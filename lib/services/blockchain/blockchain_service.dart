import '../../blockchain/ethereum_codec.dart';
import '../../models/chain_movement.dart';
import '../../models/networks.dart';
import '../../models/transaction_state.dart';
import '../../models/wallet_account.dart';
import '../../models/wallet_activity.dart';
import '../payment_service.dart';
import 'bitcoin_gateway.dart';
import 'ethereum_gateway.dart';

typedef BroadcastResult = ({String hash, bool accepted});

class PreparedTransfer {
  /// Inicializa [PreparedTransfer] com os dados recebidos.
  PreparedTransfer(this.fee, this._send, this.close);

  final BigInt fee;
  final Future<BroadcastResult> Function(Future<void> Function(String)) _send;
  final Future<void> Function() close;
  bool _started = false;

  /// Executa o envio preparado.
  Future<BroadcastResult> send(Future<void> Function(String) record) async {
    if (_started) {
      throw const FormatException(
        'Este envio já foi tentado. Consulte o histórico.',
      );
    }
    _started = true;
    return _send(record);
  }
}

/// Acesso às redes. Os gateways são mantidos durante a vida do serviço, de
/// modo que as conexões HTTP (e o TLS) são reaproveitadas entre consultas.
class BlockchainService {
  /// Inicializa [BlockchainService] com os dados recebidos.
  BlockchainService();

  final _bitcoin = <BitcoinChain, BitcoinGateway>{};
  final _ethereum = <Network, EthereumGateway>{};

  /// Reutiliza ou cria o gateway da rede Bitcoin indicada.
  BitcoinGateway _btc(BitcoinChain chain) => _bitcoin.putIfAbsent(
    chain,
    () => BitcoinGateway(chain, endpoint: chain.customEsplora),
  );

  /// Reutiliza ou cria o gateway da rede Ethereum indicada.
  EthereumGateway _eth(Network network) =>
      _ethereum.putIfAbsent(network, () => EthereumGateway(network));

  /// Consulta o saldo da conta. Para contas Multi-Coin, consulta o ativo ativo.
  Future<BigInt> balance(WalletAccount account, Network ethereum) {
    if (account.isMultiCoin) {
      if (account.activeAsset == 'BTC') {
        return _btc(account.bitcoinChain!).balance(account.btcAddress!);
      }
      return _eth(ethereum).balance(account.address);
    }
    final bitcoin = account.bitcoinChain;
    if (bitcoin != null) return _btc(bitcoin).balance(account.publicAddress);
    return _eth(ethereum).balance(account.address);
  }

  /// Consulta o saldo específico de uma moeda em uma conta Multi-Coin ou simples.
  Future<BigInt> balanceForSymbol(
    WalletAccount account,
    Network ethereum,
    String symbol,
  ) {
    if (symbol.toUpperCase() == 'BTC') {
      final chain = account.bitcoinChain ?? BitcoinChain.testnet4;
      final address = account.btcAddress ?? account.publicAddress;
      return _btc(chain).balance(address);
    }
    return _eth(ethereum).balance(account.address);
  }

  /// Prepara o envio e estima a taxa antes da confirmação.
  Future<PreparedTransfer> prepare(
    WalletAccount account,
    Network ethereum,
    Payment payment,
  ) async {
    final secret = account.secret;
    final btcSecret = account.btcSecret ?? secret;
    if (secret == null && btcSecret == null) {
      throw const FormatException('Esta carteira está em modo de observação.');
    }

    final isBtc = account.isMultiCoin
        ? account.activeAsset == 'BTC'
        : account.bitcoinChain != null;

    if (isBtc) {
      final bitcoin = account.bitcoinChain ?? BitcoinChain.testnet4;
      final btcAddress = account.btcAddress ?? account.publicAddress;
      final gateway = _btc(bitcoin);
      final quote = await gateway.quote(
        btcAddress,
        btcSecret!,
        payment.to,
        payment.amount,
      );
      return PreparedTransfer(
        quote.fee,
        (record) => gateway.send(quote, beforeBroadcast: record),
        () async {},
      );
    }

    final gateway = _eth(ethereum);
    final recipient = parseAddress(payment.to);
    final quote = await gateway.quote(account, recipient, payment.amount);
    return PreparedTransfer(
      quote.gas * quote.price.getInWei,
      (record) => gateway.send(
        account,
        recipient,
        payment.amount,
        quote,
        beforeBroadcast: record,
      ),
      () async {},
    );
  }

  /// Consulta o estado da transação na rede registrada.
  Future<TransactionState> status(WalletActivity activity) {
    if (activity.bitcoin) {
      return _btc(BitcoinChain.values.byName(activity.networkId))
          .status(activity.hash);
    }
    return _eth(Network.values.byName(activity.networkId))
        .status(activity.hash);
  }

  /// Consulta o estado da movimentação na rede registrada.
  Future<TransactionState> statusOf(ChainMovement movement) {
    if (movement.bitcoin) {
      return _btc(BitcoinChain.values.byName(movement.networkId))
          .status(movement.hash);
    }
    return _eth(Network.values.byName(movement.networkId))
        .status(movement.hash);
  }

  /// Página do extrato on-chain da carteira.
  Future<MovementPage> history(
    WalletAccount account,
    Network ethereum, {
    String? cursor,
  }) {
    final isBtc = account.isMultiCoin
        ? account.activeAsset == 'BTC'
        : account.bitcoinChain != null;

    if (isBtc) {
      final chain = account.bitcoinChain ?? BitcoinChain.testnet4;
      final btcAddress = account.btcAddress ?? account.publicAddress;
      return _btc(chain).history(btcAddress, cursor: cursor);
    }
    final ethAddress = account.ethAddress ?? account.publicAddress;
    return _eth(ethereum).history(ethAddress, cursor: cursor);
  }

  /// Libera os recursos mantidos pela instância.
  Future<void> dispose() async {
    for (final gateway in _bitcoin.values) {
      gateway.close();
    }
    for (final gateway in _ethereum.values) {
      await gateway.close();
    }
    _bitcoin.clear();
    _ethereum.clear();
  }
}
