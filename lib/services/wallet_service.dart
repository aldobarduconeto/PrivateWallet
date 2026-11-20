import '../controllers/statement_controller.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import 'blockchain/blockchain_service.dart';
import 'payment_service.dart';
import 'storage/activity_store.dart';

typedef WalletTransfer = ({
  BigInt fee,
  Future<BroadcastResult> Function() send,
  Future<void> Function() close,
});

class WalletService {
  static const balanceTtl = Duration(seconds: 45);

  final _activity = ActivityStore();
  final _blockchain = BlockchainService();
  final _balances =
      <String, ({DateTime? at, Future<BigInt>? pending, BigInt? resolved})>{};
  final _statements = <String, StatementController>{};

  /// Monta a chave de cache a partir da rede e do endereço.
  String _balanceKey(String networkId, String address) => '$networkId:$address';

  /// Resolve a rede e o endereço usados na consulta do ativo.
  ({String netId, String address}) _targetFor(
    WalletAccount account,
    Network network,
    String symbol,
  ) {
    final isBtc = symbol.toUpperCase() == 'BTC';
    final address = isBtc
        ? (account.btcAddress ?? account.publicAddress)
        : (account.ethAddress ?? account.publicAddress);
    final netId = isBtc
        ? (account.bitcoinChain?.name ?? 'testnet4')
        : network.name;
    return (netId: netId, address: address);
  }

  /// Retorna o último saldo resolvido em memória para exibição imediata na UI.
  BigInt? cachedBalance(WalletAccount account, Network network) =>
      cachedBalanceForSymbol(account, network, account.symbol);

  /// Retorna o saldo do ativo resolvido anteriormente em memória.
  BigInt? cachedBalanceForSymbol(
    WalletAccount account,
    Network network,
    String symbol,
  ) {
    final target = _targetFor(account, network, symbol);
    final key = _balanceKey(target.netId, target.address);
    return _balances[key]?.resolved;
  }

  /// Saldo do endereço na rede informada com cache de [balanceTtl].
  /// Delega unificadamente para [balanceForSymbol] eliminando redundância de chamadas.
  Future<BigInt> balance(
    WalletAccount account,
    Network network, {
    bool force = false,
  }) => balanceForSymbol(account, network, account.symbol, force: force);

  /// Consulta o saldo de um símbolo específico (ETH ou BTC) na conta,
  /// com deduplicação de requisições concorrentes (in-flight request sharing) e cache com TTL.
  Future<BigInt> balanceForSymbol(
    WalletAccount account,
    Network network,
    String symbol, {
    bool force = false,
  }) {
    final target = _targetFor(account, network, symbol);
    final key = _balanceKey(target.netId, target.address);
    final cached = _balances[key];
    final pending = cached?.pending;
    if (pending != null) return pending;
    final at = cached?.at;
    final previous = cached?.resolved;
    if (!force &&
        at != null &&
        previous != null &&
        DateTime.now().difference(at) < balanceTtl) {
      return Future.value(previous);
    }

    final value = _blockchain.balanceForSymbol(account, network, symbol);
    _balances[key] = (at: at, pending: value, resolved: previous);
    value.then<void>(
      (resolved) {
        final current = _balances[key];
        if (identical(current?.pending, value)) {
          _balances[key] = (
            at: DateTime.now(),
            pending: null,
            resolved: resolved,
          );
        }
      },
      onError: (Object _) {
        if (!identical(_balances[key]?.pending, value)) return;
        if (previous == null) {
          _balances.remove(key);
        } else {
          _balances[key] = (at: null, pending: null, resolved: previous);
        }
      },
    );
    return value;
  }

  /// Prepara o envio e estima a taxa antes da confirmação.
  Future<WalletTransfer> prepare(
    WalletAccount sender,
    Network ethereum,
    Payment payment, {
    String? purchaseName,
    String? paymentType,
  }) async {
    final type = (paymentType ?? purchaseName)?.trim();
    if (type != null && (type.isEmpty || type.length > 80)) {
      throw const FormatException(
        'Use de 1 a 80 caracteres para identificar o tipo de pagamento.',
      );
    }
    final isBtc = sender.isMultiCoin
        ? sender.activeAsset == 'BTC'
        : sender.bitcoinChain != null;
    final (netId: networkId, address: senderAddr) = _targetFor(
      sender,
      ethereum,
      isBtc ? 'BTC' : 'ETH',
    );

    final prepared = await _blockchain.prepare(sender, ethereum, payment);
    return (
      fee: prepared.fee,
      close: prepared.close,
      send: () => prepared.send((hash) async {
        _balances.remove(_balanceKey(networkId, senderAddr));
        await _activity.record(
          WalletActivity(
            hash: hash,
            networkId: networkId,
            bitcoin: isBtc,
            sender: senderAddr,
            recipient: payment.to,
            amount: payment.amount,
            fee: prepared.fee,
            created: DateTime.now(),
            purchaseName: type,
            paymentType: type,
          ),
        );
        _statements[_balanceKey(networkId, senderAddr)]?.refresh();
      }),
    );
  }

  /// Filtra os envios locais pelo endereço, ativo e rede em uso.
  Future<List<WalletActivity>> history(
    WalletAccount sender,
    Network network,
  ) async {
    final isBtc = sender.isMultiCoin
        ? sender.activeAsset == 'BTC'
        : sender.bitcoinChain != null;
    final (netId: networkId, address: senderAddr) = _targetFor(
      sender,
      network,
      isBtc ? 'BTC' : 'ETH',
    );

    return (await _activity.load())
        .where(
          (entry) =>
              entry.sender == senderAddr &&
              entry.bitcoin == isBtc &&
              entry.networkId == networkId,
        )
        .toList();
  }

  /// Reutiliza o controlador de extrato associado à rede e ao endereço.
  StatementController statement(WalletAccount account, Network network) {
    final isBtc = account.isMultiCoin
        ? account.activeAsset == 'BTC'
        : account.bitcoinChain != null;
    final (netId: networkId, :address) = _targetFor(
      account,
      network,
      isBtc ? 'BTC' : 'ETH',
    );

    final key = _balanceKey(networkId, address);
    return _statements.putIfAbsent(
      key,
      () => StatementController(
        fetch: (cursor) =>
            _blockchain.history(account, network, cursor: cursor),
        localSends: () => history(account, network),
      ),
    );
  }

  /// Atualiza manualmente o saldo em cache de um ativo (útil após swaps ou ajustes).
  void setCachedBalance(
    WalletAccount account,
    Network network,
    String symbol,
    BigInt newBalance,
  ) {
    final target = _targetFor(account, network, symbol);
    final key = _balanceKey(target.netId, target.address);
    _balances[key] = (
      at: DateTime.now().add(const Duration(minutes: 30)),
      pending: null,
      resolved: newBalance,
    );
    _statements[key]?.refresh();
  }

  /// Registra uma atividade manualmente no histórico local (como uma troca de moedas).
  Future<void> recordActivity(WalletActivity activity) async {
    await _activity.record(activity);
    final key = _balanceKey(activity.networkId, activity.sender);
    _statements[key]?.refresh();
  }
}
