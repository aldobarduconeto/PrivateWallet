import '../controllers/statement_controller.dart';
import '../models/networks.dart';
import '../models/fiat_currency.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import '../services/crypto_finance_service.dart';
import '../services/payment_service.dart';
import '../services/storage/wallet_store.dart';
import '../services/wallet_service.dart';

export '../services/wallet_service.dart' show WalletTransfer;

class WalletController {
  /// Inicializa [WalletController] com os dados recebidos.
  WalletController(this.network);

  static const balanceTtl = WalletService.balanceTtl;

  final _store = WalletStore();
  final _wallet = WalletService();
  List<WalletAccount> _accounts = [];
  int _selected = 0;
  Network network;

  /// Mantém referência à conta ativa atual para consultas de ações do cabeçalho.
  static WalletAccount? currentAccount;

  /// Retorna as contas em uso.
  List<WalletAccount> get accounts => _accounts;

  /// Retorna `selected` para consulta em carteira.
  int get selected => _selected;

  /// Retorna a conta em uso.
  WalletAccount get account => _accounts[_selected];

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    _accounts = List.unmodifiable(await _store.load());
    if (_accounts.isNotEmpty && _selected < _accounts.length) {
      currentAccount = _accounts[_selected];
    }
  }

  /// Atualiza o item usado nas próximas operações.
  void select(int index) {
    RangeError.checkValidIndex(index, _accounts);
    _selected = index;
    currentAccount = _accounts[_selected];
  }

  /// Alterna o ativo em foco na carteira Multi-Moeda (ETH <-> BTC).
  Future<void> setActiveAsset(String symbol) async {
    if (!account.isMultiCoin) return;
    final updated = [..._accounts];
    updated[_selected] = account.copyWith(activeAsset: symbol.toUpperCase());
    await _save(updated);
  }

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> add(WalletAccount account) async {
    final updated = [..._accounts];
    final existing = updated.indexWhere(
      (item) =>
          item.publicAddress == account.publicAddress &&
          item.bitcoinChain == account.bitcoinChain &&
          item.isMultiCoin == account.isMultiCoin,
    );
    if (existing == -1) {
      updated.add(account);
    } else if (!updated[existing].canSign && account.canSign) {
      updated[existing] = account;
    } else {
      throw const FormatException(
        'Este endereço ou carteira já está na sua lista.',
      );
    }
    await _save(updated);
    _selected = existing == -1 ? updated.length - 1 : existing;
  }

  /// Adiciona uma lista de contas (útil para espelhamento de contas).
  /// Ignora contas que já existam na lista e atualiza contas watch-only caso a nova possua chave.
  Future<int> addAll(List<WalletAccount> newAccounts) async {
    final updated = [..._accounts];
    var addedCount = 0;
    for (final account in newAccounts) {
      final existing = updated.indexWhere(
        (item) =>
            item.publicAddress == account.publicAddress &&
            item.bitcoinChain == account.bitcoinChain &&
            item.isMultiCoin == account.isMultiCoin,
      );
      if (existing == -1) {
        updated.add(account);
        addedCount++;
      } else if (!updated[existing].canSign && account.canSign) {
        updated[existing] = account;
        addedCount++;
      }
    }
    if (addedCount > 0) {
      await _save(updated);
      _selected = updated.length - 1;
    }
    return addedCount;
  }

  /// Salva o novo nome da carteira selecionada.
  Future<void> rename(String name) async {
    final updated = [..._accounts];
    updated[_selected] = account.copyWith(name: name);
    await _save(updated);
  }

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> remove() async {
    final updated = [..._accounts]..removeAt(_selected);
    await _save(updated);
    if (_selected >= updated.length) {
      _selected = updated.isEmpty ? 0 : updated.length - 1;
    }
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> _save(List<WalletAccount> updated) async {
    await _store.save(updated);
    _accounts = List.unmodifiable(updated);
  }

  /// Consulta o saldo da carteira na rede selecionada.
  Future<BigInt> balance({bool force = false}) =>
      _wallet.balance(account, network, force: force);

  /// Retorna o último saldo disponível em memória.
  BigInt? lastKnownBalance() => _wallet.cachedBalance(account, network);

  /// Consulta o saldo do ativo indicado sem alterar a seleção da carteira.
  Future<BigInt> balanceForSymbol(String symbol, {bool force = false}) =>
      _wallet.balanceForSymbol(account, network, symbol, force: force);

  /// Retorna o último saldo disponível em memória para o ativo indicado.
  BigInt? lastKnownBalanceForSymbol(String symbol) =>
      _wallet.cachedBalanceForSymbol(account, network, symbol);

  /// Calcula os valores por carteira e soma endereços únicos das redes principais.
  Future<({List<double?> wallets, double? total})> portfolioValue(
    FiatCurrency currency, {
    required Future<double?> exchangeRate,
    bool force = false,
  }) async {
    const finance = CryptoFinanceService();
    final ethereum = network;
    final assets = <(String, String), Future<double?>>{};

    /// Consulta o saldo do ativo e o converte se houver taxa disponível.
    Future<double?> valueOf(WalletAccount wallet, String symbol) async {
      try {
        final balance = await _wallet.balanceForSymbol(
          wallet,
          ethereum,
          symbol,
          force: force,
        );
        final rate = await exchangeRate;
        return rate == null
            ? null
            : finance.valueIn(balance, symbol, currency, rate);
      } catch (_) {
        return null;
      }
    }

    /// Soma os valores conhecidos e sinaliza quando falta um saldo.
    double? sum(List<double?> values) {
      if (values.contains(null)) return null;
      return values.fold<double>(0.0, (total, value) => total + value!);
    }

    final wallets = await Future.wait(
      accounts.map((wallet) async {
        final eth = wallet.ethAddress;
        final btc = wallet.btcAddress;
        return sum(
          await Future.wait([
            if (ethereum == Network.mainnet && eth != null && eth.isNotEmpty)
              assets.putIfAbsent((
                'ETH',
                eth.toLowerCase(),
              ), () => valueOf(wallet, 'ETH')),
            if (wallet.bitcoinChain == BitcoinChain.mainnet &&
                btc != null &&
                btc.isNotEmpty)
              assets.putIfAbsent(('BTC', btc), () => valueOf(wallet, 'BTC')),
          ]),
        );
      }),
    );
    return (wallets: wallets, total: sum(await Future.wait(assets.values)));
  }

  /// Prepara o envio e estima a taxa antes da confirmação.
  Future<WalletTransfer> prepare(
    Payment payment, {
    String? purchaseName,
    String? paymentType,
  }) => _wallet.prepare(
    account,
    network,
    payment,
    purchaseName: purchaseName,
    paymentType: paymentType,
  );

  /// Consulta o histórico conforme os filtros e a paginação recebidos.
  Future<List<WalletActivity>> history() => _wallet.history(account, network);

  /// Monta o extrato com o estado atual.
  StatementController statement() => _wallet.statement(account, network);
}
