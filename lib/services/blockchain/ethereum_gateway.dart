import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../../blockchain/ethereum_signer.dart';
import '../../models/chain_movement.dart';
import '../../models/networks.dart';
import '../../models/transaction_state.dart';
import '../../models/wallet_account.dart';
import 'network_retry.dart';

typedef TransferQuote = ({BigInt gas, EtherAmount price});

class EthereumGateway {
  /// Inicializa [EthereumGateway] com os dados recebidos.
  EthereumGateway(this.network, {http.Client? transport})
    : _http = transport ?? http.Client() {
    final primary = '${network.rpcUri}';
    _endpoints = [
      primary,
      // Alternativa pública, usada apenas sem endpoint próprio configurado.
      if (network.rpcUri.host == network.rpc) ?_fallbackRpc[network],
    ];
  }

  static const _fallbackRpc = {
    Network.sepolia: 'https://sepolia.drpc.org',
    Network.mainnet: 'https://eth.drpc.org',
  };

  final Network network;
  final http.Client _http;
  late final List<String> _endpoints;
  final _clients = <int, Web3Client>{};

  /// Tempo por tentativa: falhas trocam de nó em vez de travar a tela.
  static const _timeout = Duration(seconds: 8);
  static const _pageSize = 25;

  /// Nó que respondeu por último em cada rede.
  static final _preferred = <Network, int>{};

  /// Endpoints cujo chain ID já foi conferido nesta execução.
  static final _verified = <String>{};

  /// Obtém o cliente usado para consultar a rede.
  Web3Client _client(int index) => _clients.putIfAbsent(
    index,
    () => Web3Client(_endpoints[index].toString(), _http),
  );

  /// Confere se o endpoint Ethereum aponta para a rede selecionada.
  Future<void> _verifyNetwork(int index) async {
    final key = _endpoints[index].toString();
    if (_verified.contains(key)) return;
    if (await _client(index).getChainId().timeout(_timeout) !=
        BigInt.from(network.chainId)) {
      throw const FormatException(
        'O servidor respondeu com uma rede diferente.',
      );
    }
    _verified.add(key);
  }

  /// Leitura com nova tentativa e troca automática de nó.
  Future<T> _read<T>(Future<T> Function(Web3Client client) op) async {
    final start = _preferred[network] ?? 0;
    Object? lastError;
    for (var offset = 0; offset < _endpoints.length; offset++) {
      final index = (start + offset) % _endpoints.length;
      try {
        final result = await withRetry(() async {
          await _verifyNetwork(index);
          return op(_client(index)).timeout(_timeout);
        }, attempts: 2);
        _preferred[network] = index;
        return result;
      } on Object catch (error) {
        if (!isTransient(error)) rethrow;
        lastError = error;
      }
    }
    throw FormatException(
      lastError is TimeoutException
          ? 'O nó Ethereum demorou a responder.'
          : 'O nó Ethereum está indisponível.',
    );
  }

  /// Consulta o saldo da carteira na rede selecionada.
  Future<BigInt> balance(EthereumAddress address) async =>
      (await _read((client) => client.getBalance(address))).getInWei;

  /// Estima a taxa e reúne os dados necessários para preparar a transferência.
  Future<TransferQuote> quote(
    WalletAccount account,
    EthereumAddress to,
    BigInt wei,
  ) async {
    // Saldo pendente e preço do gás são independentes: em paralelo.
    final (pending, price) = await _quoteInputs(account.address);
    final funds = pending.getInWei;
    if (funds < wei) throw const FormatException('Saldo insuficiente.');
    final gas = await _read(
      (client) => client.estimateGas(
        sender: account.address,
        to: to,
        gasPrice: price,
        value: EtherAmount.inWei(wei),
      ),
    );
    if (funds < wei + gas * price.getInWei) {
      throw const FormatException('Saldo insuficiente para o valor e a taxa.');
    }
    return (gas: gas, price: price);
  }

  /// Estima `inputs` no fluxo de ethereum gateway.
  Future<(EtherAmount, EtherAmount)> _quoteInputs(
    EthereumAddress sender,
  ) async {
    try {
      return await (
        _read(
          (client) =>
              client.getBalance(sender, atBlock: const BlockNum.pending()),
        ),
        _read((client) => client.getGasPrice()),
      ).wait;
    } on ParallelWaitError<
      (EtherAmount?, EtherAmount?),
      (AsyncError?, AsyncError?)
    > catch (failure) {
      final (a, b) = failure.errors;
      final first = (a ?? b)!;
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  /// Executa o envio preparado.
  Future<({String hash, bool accepted})> send(
    WalletAccount account,
    EthereumAddress to,
    BigInt wei,
    TransferQuote quote, {
    Future<void> Function(String hash)? beforeBroadcast,
  }) async {
    final nonce = await _read(
      (client) => client.getTransactionCount(
        account.address,
        atBlock: const BlockNum.pending(),
      ),
    );
    final signed = signEthereumTransfer(
      network: network,
      secret: account.secret!,
      sender: account.address,
      recipient: to,
      wei: wei,
      nonce: nonce,
      gasPrice: quote.price,
      gasLimit: quote.gas.toInt(),
    );
    final hash = bytesToHex(
      keccak256(signed),
      include0x: true,
      padToEvenLength: true,
    );
    await beforeBroadcast?.call(hash);
    try {
      // Transmissão sem repetição automática: usa o nó que respondeu por último.
      final returnedHash = await _client(_preferred[network] ?? 0)
          .sendRawTransaction(signed)
          .timeout(const Duration(seconds: 15));
      return (hash: hash, accepted: returnedHash.toLowerCase() == hash);
    } on Exception {
      return (hash: hash, accepted: false);
    }
  }

  /// Consulta o estado da transação na rede registrada.
  Future<TransactionState> status(String hash) async {
    final receipt = await _read((client) => client.getTransactionReceipt(hash));
    if (receipt != null) {
      return receipt.status == false
          ? TransactionState.reverted
          : TransactionState.included;
    }
    final tx = await _read((client) => client.getTransactionByHash(hash));
    return tx == null ? TransactionState.unseen : TransactionState.pending;
  }

  /// Movimentações em ETH nativo pelo indexador público (API compatível
  /// com Etherscan, sem chave). [cursor] é o número da próxima página.
  Future<MovementPage> history(String address, {String? cursor}) async {
    final page = int.tryParse(cursor ?? '1');
    if (page == null || page < 1) {
      throw const FormatException('Cursor de extrato inválido.');
    }
    final own = address.toLowerCase();
    final url = Uri.https(network.indexer, '/api', {
      'module': 'account',
      'action': 'txlist',
      'address': address,
      'page': '$page',
      'offset': '$_pageSize',
      'sort': 'desc',
    });
    final response =
        await withRetry(() async {
          final response = await _http.get(url).timeout(_timeout);
          if (TransientHttpError.matches(response.statusCode)) {
            throw TransientHttpError(response.statusCode);
          }
          return response;
        }).catchError(
          (Object _) => throw const FormatException(
            'O indexador Ethereum está indisponível. Tente novamente.',
          ),
          test: isTransient,
        );
    final data = response.statusCode == 200 ? jsonDecode(response.body) : null;
    final rows = data is Map ? data['result'] : null;
    if (rows is! List) {
      throw const FormatException(
        'O indexador Ethereum retornou dados inconsistentes.',
      );
    }
    final items = <ChainMovement>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final hash = row['hash'];
      final from = (row['from'] as String?)?.toLowerCase();
      final to = (row['to'] as String?)?.toLowerCase();
      final value = BigInt.tryParse('${row['value']}');
      if (hash is! String || value == null) continue;
      final outgoing = from == own;
      final incoming = to == own;
      final type = outgoing && incoming
          ? MovementType.self
          : outgoing
          ? MovementType.outgoing
          : MovementType.incoming;
      final gasUsed = BigInt.tryParse('${row['gasUsed']}');
      final gasPrice = BigInt.tryParse('${row['gasPrice']}');
      final seconds = int.tryParse('${row['timeStamp']}');
      items.add(
        ChainMovement(
          hash: hash,
          type: type,
          amount: type == MovementType.self ? BigInt.zero : value,
          bitcoin: false,
          networkId: network.name,
          fee: outgoing && gasUsed != null && gasPrice != null
              ? gasUsed * gasPrice
              : null,
          counterparty: outgoing
              ? row['to'] as String?
              : row['from'] as String?,
          time: seconds == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  seconds * 1000,
                  isUtc: true,
                ),
          failed: row['isError'] == '1',
        ),
      );
    }
    return (
      items: items,
      cursor: rows.length >= _pageSize ? '${page + 1}' : null,
    );
  }

  /// Encerra os recursos usados pela operação.
  Future<void> close() async {
    for (final client in _clients.values) {
      await client.dispose();
    }
    _clients.clear();
    _http.close();
  }
}
