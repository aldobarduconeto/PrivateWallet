import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:http/http.dart' as http;

import '../../blockchain/bitcoin_codec.dart';
import '../../blockchain/bitcoin_signer.dart';
import '../../models/chain_movement.dart';
import '../../models/networks.dart';
import '../../models/transaction_state.dart';
import 'network_retry.dart';

final _minimumPayment = BigInt.from(546);
final _minimumChange = BigInt.from(294);

class BitcoinQuote {
  /// Inicializa [BitcoinQuote] com os dados recebidos.
  const BitcoinQuote._(this._transaction, this.fee, this._chain);
  final BtcTransaction _transaction;
  final BigInt fee;
  final BitcoinChain _chain;
}

class BitcoinGateway {
  /// Usa [endpoint] (URL base Esplora) quando informado; caso contrário, os
  /// serviços públicos da rede, com troca automática quando um falha.
  BitcoinGateway(this.chain, {Uri? endpoint, http.Client? transport})
    : _endpoints = endpoint == null
          ? chain.publicEsplora
          : [_withSlash(endpoint)],
      _custom = endpoint != null,
      _http = transport ?? http.Client();

  final BitcoinChain chain;
  final List<Uri> _endpoints;
  final bool _custom;
  final http.Client _http;

  /// Tempo por tentativa. Curto o bastante para trocar de serviço rápido.
  static const _timeout = Duration(seconds: 8);
  static final _txidPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Serviço que respondeu por último, por rede: as próximas consultas
  /// começam por ele.
  static final _preferred = <BitcoinChain, int>{};

  /// Endpoints próprios já validados pelo bloco gênese.
  static final _verified = <String>{};

  /// Normaliza a barra usada para compor o caminho da requisição.
  static Uri _withSlash(Uri uri) =>
      uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');

  /// Valida o endpoint Esplora personalizado antes de reutilizá-lo.
  Future<void> _verifyCustom(Uri base) async {
    if (!_custom || _verified.contains('$base')) return;
    final response = await _http
        .get(base.resolve('block-height/0'))
        .timeout(_timeout);
    if (response.statusCode != 200 || response.body.trim() != chain.genesis) {
      throw const FormatException(
        'O servidor Bitcoin configurado pertence a outra rede.',
      );
    }
    _verified.add('$base');
  }

  /// Requisição com nova tentativa e troca de serviço em falhas transitórias.
  Future<http.Response> _request(
    String path, {
    Future<http.Response> Function(Uri url)? send,
    bool retry = true,
  }) async {
    final start = _preferred[chain] ?? 0;
    Object? lastError;
    for (var offset = 0; offset < _endpoints.length; offset++) {
      final index = (start + offset) % _endpoints.length;
      final base = _endpoints[index];
      try {
        await _verifyCustom(base);
        final url = base.resolve(
          path.startsWith('/') ? path.substring(1) : path,
        );

        /// Executa a requisição Bitcoin usando o endpoint selecionado.
        Future<http.Response> call() async {
          final response = await (send?.call(url) ?? _http.get(url)).timeout(
            _timeout,
          );
          if (TransientHttpError.matches(response.statusCode)) {
            throw TransientHttpError(response.statusCode);
          }
          return response;
        }

        final response = retry
            ? await withRetry(call, attempts: 2)
            : await call();
        _preferred[chain] = index;
        return response;
      } on Object catch (error) {
        if (!isTransient(error)) rethrow;
        lastError = error;
      }
    }
    if (lastError is TimeoutException) {
      throw const FormatException('O serviço Bitcoin demorou a responder.');
    }
    throw const FormatException('O serviço Bitcoin está indisponível.');
  }

  /// Executa a consulta ao endpoint usando o cliente configurado.
  Future<String> _get(String path) async {
    final response = await _request(path);
    if (response.statusCode != 200) {
      throw const FormatException(
        'O serviço Bitcoin não respondeu à consulta.',
      );
    }
    return response.body;
  }

  /// Busca as saídas confirmadas que podem financiar uma transferência.
  Future<List<BitcoinUtxo>> _confirmedOutputs(BitcoinAddress address) async {
    final data = jsonDecode(await _get('/address/${address.address}/utxo'));
    const invalid = FormatException(
      'O serviço Bitcoin retornou dados inconsistentes.',
    );
    if (data is! List) throw invalid;
    final outputs = <BitcoinUtxo>[];
    final seen = <String>{};
    for (final item in data) {
      if (item is! Map<String, dynamic> ||
          item['status'] is! Map<String, dynamic>) {
        throw invalid;
      }
      final status = item['status'] as Map<String, dynamic>;
      if (status['confirmed'] != true) continue;
      final hash = item['txid'];
      final value = item['value'];
      final index = item['vout'];
      final height = status['block_height'];
      if (hash is! String ||
          !_txidPattern.hasMatch(hash) ||
          value is! int ||
          value < 0 ||
          value > maxSatoshis ||
          index is! int ||
          index < 0 ||
          index > 0xffffffff ||
          height is! int ||
          height < 0 ||
          !seen.add('$hash:$index')) {
        throw invalid;
      }
      if (value == 0) continue;
      outputs.add(
        BitcoinUtxo(
          txHash: hash,
          value: BigInt.from(value),
          vout: index,
          blockHeight: height,
          scriptType: address.baseAddress.type,
        ),
      );
    }
    return outputs;
  }

  /// Consulta o saldo da carteira na rede selecionada.
  Future<BigInt> balance(String address) async {
    final parsed = parseBitcoinAddress(chain, address);
    final outputs = await _confirmedOutputs(parsed);
    return outputs.fold<BigInt>(
      BigInt.zero,
      (total, output) => total + output.value,
    );
  }

  /// Obtém a taxa por unidade de tamanho para preparar a transação.
  Future<int> _feeRate() async {
    final fees = jsonDecode(await _get('/fee-estimates'));
    if (fees is! Map<String, dynamic>) {
      throw const FormatException('Estimativa de taxa Bitcoin indisponível.');
    }
    // Testnet4 may expose only long targets when few blocks have been mined.
    final targets =
        fees.keys
            .map(int.tryParse)
            .whereType<int>()
            .where((target) => target > 0)
            .toList()
          ..sort((a, b) => (a - 6).abs().compareTo((b - 6).abs()));
    for (final target in targets) {
      final rate = fees['$target'];
      if (rate is num && rate.isFinite && rate > 0 && rate <= 1000) {
        return max(1, rate.ceil());
      }
    }
    throw const FormatException('Estimativa de taxa Bitcoin indisponível.');
  }

  /// Consulta a altura atual da cadeia Bitcoin.
  Future<int> _tipHeight() async {
    final tip = int.tryParse((await _get('/blocks/tip/height')).trim());
    if (tip == null || tip < 0) {
      throw const FormatException(
        'Não foi possível verificar a altura da rede Bitcoin.',
      );
    }
    return tip;
  }

  /// Verifica se a saída atingiu a maturidade exigida pela rede.
  Future<bool> _isMature(BitcoinUtxo output, int tip) async {
    if (tip - output.blockHeight >= 100) return true;
    final tx = jsonDecode(await _get('/tx/${output.txHash}'));
    final inputs = tx is Map ? tx['vin'] : null;
    if (inputs is! List ||
        inputs.isEmpty ||
        inputs.first is! Map ||
        inputs.first['is_coinbase'] is! bool) {
      throw const FormatException(
        'Não foi possível verificar a origem da saída Bitcoin.',
      );
    }
    return inputs.first['is_coinbase'] == false;
  }

  /// Estima a taxa e reúne os dados necessários para preparar a transferência.
  Future<BitcoinQuote> quote(
    String address,
    String wif,
    String destination,
    BigInt amount,
  ) async {
    if (amount < _minimumPayment || amount > BigInt.from(maxSatoshis)) {
      throw const FormatException(
        'Envie pelo menos 546 satoshis e um valor válido.',
      );
    }
    final sender = parseBitcoinAddress(chain, address);
    final recipient = parseBitcoinAddress(chain, destination);
    final key = importBitcoinKey(chain, wif);
    if (bitcoinAddressForKey(chain, key) != sender.address) {
      throw const FormatException(
        'A chave não corresponde ao endereço Bitcoin.',
      );
    }
    // Saídas, altura e taxa são independentes: consultadas em paralelo.
    final (available, tip, rate) = await _quoteInputs(sender);
    const insufficient = FormatException(
      'Saldo Bitcoin confirmado insuficiente para o valor e a taxa.',
    );
    if (available.isEmpty) throw insufficient;
    available.sort((a, b) => b.value.compareTo(a.value));
    final candidates = available
        .take(100)
        .where((output) => output.blockHeight <= tip)
        .toList();
    // Verifica a maturidade das saídas recentes de uma vez, não uma a uma.
    final mature = await Future.wait([
      for (final output in candidates) _isMature(output, tip),
    ]);
    final recipientSize = 9 + recipient.toScriptPubKey().toBytes().length;
    final selected = <BitcoinUtxo>[];
    var total = BigInt.zero;
    for (var i = 0; i < candidates.length; i++) {
      if (!mature[i]) continue;
      final output = candidates[i];
      selected.add(output);
      total += output.value;
      // Conservative vbyte bound for up to 100 native SegWit inputs.
      final vsize = 12 + 69 * selected.length + recipientSize;
      final remaining = total - amount;
      final feeWithoutChange = BigInt.from(rate * vsize);
      if (remaining < feeWithoutChange) continue;

      final feeWithChange = BigInt.from(rate * (vsize + 31));
      final change = remaining - feeWithChange;
      final hasChange = change >= _minimumChange;
      final fee = hasChange ? feeWithChange : remaining;
      final transaction = signBitcoinTransfer(
        chain: chain,
        key: key,
        sender: sender,
        recipient: recipient,
        inputs: selected,
        amount: amount,
        fee: fee,
        change: hasChange ? change : BigInt.zero,
      );
      if (fee < BigInt.from(rate * transaction.getVSize())) {
        throw const FormatException(
          'A taxa calculada é insuficiente para a transação.',
        );
      }
      return BitcoinQuote._(transaction, fee, chain);
    }
    throw insufficient;
  }

  /// Estima `inputs` no fluxo de bitcoin gateway.
  Future<(List<BitcoinUtxo>, int, int)> _quoteInputs(
    BitcoinAddress sender,
  ) async {
    try {
      return await (_confirmedOutputs(sender), _tipHeight(), _feeRate()).wait;
    } on ParallelWaitError<
      (List<BitcoinUtxo>?, int?, int?),
      (AsyncError?, AsyncError?, AsyncError?)
    > catch (failure) {
      final (a, b, c) = failure.errors;
      final first = (a ?? b ?? c)!;
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  /// Executa o envio preparado.
  Future<({String hash, bool accepted})> send(
    BitcoinQuote quote, {
    Future<void> Function(String hash)? beforeBroadcast,
  }) async {
    if (quote._chain != chain) {
      throw const FormatException(
        'A transação foi preparada para outra rede Bitcoin.',
      );
    }
    final hash = quote._transaction.txId();
    await beforeBroadcast?.call(hash);
    try {
      // A transmissão é idempotente pelo txid: em falha de rede o próximo
      // serviço recebe a mesma transação assinada.
      final response = await _request(
        '/tx',
        retry: false,
        send: (url) => _http.post(
          url,
          headers: {'content-type': 'text/plain'},
          body: quote._transaction.serialize(),
        ),
      );
      return (
        hash: hash,
        accepted: response.statusCode == 200 && response.body.trim() == hash,
      );
    } on Exception {
      return (hash: hash, accepted: false);
    }
  }

  /// Consulta o estado da transação na rede registrada.
  Future<TransactionState> status(String hash) async {
    if (!_txidPattern.hasMatch(hash)) {
      throw const FormatException('Hash Bitcoin inválido.');
    }
    final response = await _request('/tx/$hash/status');
    if (response.statusCode == 404) return TransactionState.unseen;
    if (response.statusCode == 200) {
      if (jsonDecode(response.body) case {'confirmed': final bool confirmed}) {
        return confirmed ? TransactionState.included : TransactionState.pending;
      }
    }
    throw const FormatException('Não foi possível consultar o status Bitcoin.');
  }

  /// Movimentações do endereço, mais recentes primeiro. A primeira página
  /// inclui transações no mempool; [cursor] é o último txid confirmado.
  Future<MovementPage> history(String address, {String? cursor}) async {
    final parsed = parseBitcoinAddress(chain, address).address;
    if (cursor != null && !_txidPattern.hasMatch(cursor)) {
      throw const FormatException('Cursor de extrato inválido.');
    }
    final data = jsonDecode(
      await _get(
        cursor == null
            ? '/address/$parsed/txs'
            : '/address/$parsed/txs/chain/$cursor',
      ),
    );
    if (data is! List) {
      throw const FormatException(
        'O serviço Bitcoin retornou dados inconsistentes.',
      );
    }
    final items = <ChainMovement>[];
    String? lastConfirmed;
    var confirmedCount = 0;
    for (final tx in data.whereType<Map<String, dynamic>>()) {
      final movement = _movement(tx, parsed);
      if (movement == null) continue;
      items.add(movement);
      if (movement.confirmed) {
        confirmedCount++;
        lastConfirmed = movement.hash;
      }
    }
    // O Esplora devolve 25 confirmadas por página; menos indica o fim.
    return (items: items, cursor: confirmedCount >= 25 ? lastConfirmed : null);
  }

  /// Monta a movimentação com o estado atual.
  ChainMovement? _movement(Map<String, dynamic> tx, String address) {
    final hash = tx['txid'];
    if (hash is! String || !_txidPattern.hasMatch(hash)) return null;
    var received = BigInt.zero;
    var spent = BigInt.zero;
    String? firstSender;
    String? firstRecipient;
    for (final input in (tx['vin'] as List? ?? const [])) {
      final prevout = input is Map ? input['prevout'] : null;
      if (prevout is! Map) continue;
      final owner = prevout['scriptpubkey_address'];
      final value = prevout['value'];
      if (owner == address && value is int) {
        spent += BigInt.from(value);
      } else if (owner is String) {
        firstSender ??= owner;
      }
    }
    for (final output in (tx['vout'] as List? ?? const [])) {
      if (output is! Map) continue;
      final owner = output['scriptpubkey_address'];
      final value = output['value'];
      if (owner == address && value is int) {
        received += BigInt.from(value);
      } else if (owner is String) {
        firstRecipient ??= owner;
      }
    }
    final status = tx['status'];
    final confirmed = status is Map && status['confirmed'] == true;
    final blockTime = status is Map ? status['block_time'] : null;
    final fee = tx['fee'] is int ? BigInt.from(tx['fee'] as int) : null;
    final MovementType type;
    final BigInt amount;
    if (spent == BigInt.zero) {
      type = MovementType.incoming;
      amount = received;
    } else if (firstRecipient == null) {
      type = MovementType.self;
      amount = BigInt.zero;
    } else {
      type = MovementType.outgoing;
      // Valor enviado a terceiros = gasto − troco − taxa.
      amount = spent - received - (fee ?? BigInt.zero);
    }
    return ChainMovement(
      hash: hash,
      type: type,
      amount: amount < BigInt.zero ? BigInt.zero : amount,
      bitcoin: true,
      networkId: chain.name,
      fee: type == MovementType.incoming ? null : fee,
      counterparty: type == MovementType.incoming
          ? firstSender
          : firstRecipient,
      time: blockTime is int
          ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000, isUtc: true)
          : null,
      confirmed: confirmed,
    );
  }

  /// Encerra os recursos usados pela operação.
  void close() => _http.close();
}
