import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/auto_debit_controller.dart';
import '../controllers/budget_controller.dart';
import '../controllers/contacts_controller.dart';
import '../controllers/goals_controller.dart';
import '../controllers/group_purchase_controller.dart';
import '../controllers/vaults_controller.dart';
import '../controllers/wallet_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/crypto_vault.dart';
import '../models/auto_debit_plan.dart';
import '../models/fiat_currency.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import '../models/wallet_contact.dart';
import '../models/wallet_preferences.dart';
import '../services/payment_service.dart';
import '../services/fiat_exchange_service.dart';
import '../services/gas_tracker_service.dart';
import '../services/system/auth_protection_service.dart';
import '../services/system/background_sync_service.dart';
import '../services/system/clipboard_guard_service.dart';
import '../services/system/header_command_service.dart';
import '../services/system/security_shield_service.dart';
import '../services/wallet_sync_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/crypto_receipt_dialog.dart';
import '../widgets/crypto_receive_qr_sheet.dart';
import '../widgets/header_quick_search_dialog.dart';
import '../widgets/multi_coin_balance_card.dart';
import '../widgets/address_inspector_dialog.dart';
import '../widgets/wallet_form.dart';
import '../widgets/wallet_widgets.dart';
import 'app_lock_screen.dart';
import 'crypto_market_screen.dart';
import 'crypto_pos_screen.dart';
import 'gas_tracker_screen.dart';
import 'privacy_stealth_screen.dart';
import 'wallet_account_screen.dart';
import 'wallet_activity_screen.dart';
import 'wallet_auto_debit_screen.dart';
import 'wallet_contacts_screen.dart';
import 'wallet_finance_screen.dart';
import 'wallet_settings_screen.dart';
import 'wallet_statement_screen.dart';
import 'wallet_sync_screen.dart';
import 'welcome_onboarding_screen.dart';

enum AccountMode {
  create('Criar carteira', Icons.add_circle_outline),
  import('Importar chave privada', Icons.key_outlined),
  watch('Acompanhar endereço', Icons.visibility_outlined);

  /// Inicializa a configuração de painel.
  const AccountMode(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Seleciona o rótulo da ação no idioma atual.
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    create => l10n.createWallet,
    import => l10n.importPrivateKey,
    watch => l10n.watchAddress,
  };
}

enum WalletKind {
  multiCoinTestnet(
    'Multi-Moeda · ETH + BTC (Testnet4)',
    bitcoin: BitcoinChain.testnet4,
    isMulti: true,
  ),
  multiCoinMainnet(
    'Multi-Moeda · ETH + BTC (Principal)',
    bitcoin: BitcoinChain.mainnet,
    isMulti: true,
  ),
  ethereum('Ethereum · Somente ETH'),
  bitcoinTestnet('Bitcoin · Somente Testnet4', bitcoin: BitcoinChain.testnet4),
  bitcoinMainnet(
    'Bitcoin · Somente rede principal',
    bitcoin: BitcoinChain.mainnet,
  );

  /// Inicializa a configuração de painel.
  const WalletKind(this.label, {this.bitcoin, this.isMulti = false});
  final String label;
  final BitcoinChain? bitcoin;
  final bool isMulti;
}

class WalletHome extends StatefulWidget {
  /// Inicializa [WalletHome] com os dados recebidos.
  const WalletHome({
    super.key,
    required this.preferences,
    required this.savePreferences,
  });

  final ValueListenable<WalletPreferences> preferences;
  final Future<void> Function(WalletPreferences) savePreferences;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> with WidgetsBindingObserver {
  late final WalletController _controller;
  final _contacts = ContactsController();
  final _goals = GoalsController();
  final _vaults = VaultsController();
  final _budget = BudgetController();
  final _autoDebits = AutoDebitController();
  final _groupPurchases = GroupPurchaseController();

  /// Retorna as contas em uso.
  List<WalletAccount> get _accounts => _controller.accounts;

  /// Retorna `selected` para consulta em painel.
  int get _selected => _controller.selected;

  /// Retorna a rede em uso.
  Network get _network => _controller.network;
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;
  bool _settingsOpen = false;
  bool _isLocked = false;
  late bool _hideBalance;
  late Future<BigInt> _balance;
  late Future<({List<double?> wallets, double? total})> _portfolioValue;
  late Future<double?> _exchangeRate;

  /// Retorna a moeda de comparação em uso.
  FiatCurrency get _fiatCurrency => widget.preferences.value.fiatCurrency;
  BigInt? _cachedEthBalance;
  BigInt? _cachedBtcBalance;
  int _balanceRevision = 0;
  Future<List<WalletActivity>> _recent = Future.value(const []);

  /// Retorna a conta em uso.
  WalletAccount get _account => _controller.account;

  /// Retorna as cores do tema do contexto atual.
  ColorScheme get _colors => Theme.of(context).colorScheme;

  /// Retorna o rótulo da rede em uso.
  String get _networkLabel {
    if (_accounts.isEmpty) return _network.label;
    if (_account.isMultiCoin) {
      final btc = _account.bitcoinChain?.label ?? 'Testnet4';
      return 'Multi-Moeda · ${_network.label} & $btc';
    }
    return _account.bitcoinChain?.label ?? _network.label;
  }

  /// Formata o valor.
  String _formatAmount(BigInt amount) {
    if (_accounts.isEmpty) return formatEth(amount);
    final isBtc = _account.isMultiCoin
        ? _account.activeAsset == 'BTC'
        : _account.bitcoinChain != null;
    return isBtc ? formatBtc(amount) : formatEth(amount);
  }

  /// Prepara a solicitação de pagamento para compartilhar.
  String _paymentRequest(String address, BigInt? amount) {
    if (_accounts.isEmpty) return '';
    final isBtc = _account.isMultiCoin
        ? _account.activeAsset == 'BTC'
        : _account.bitcoinChain != null;
    if (isBtc) {
      final bitcoin = _account.bitcoinChain ?? BitcoinChain.testnet4;
      return bitcoinPaymentLink(bitcoin, address, amount);
    }
    return paymentLink(_network, parseAddress(address), amount);
  }

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _controller = WalletController(widget.preferences.value.ethereumNetwork);
    _hideBalance = widget.preferences.value.hideBalanceAtStartup;
    _balance = Future.value(BigInt.zero);
    _portfolioValue = Future.value((wallets: <double?>[], total: null));
    _exchangeRate = Future.value(null);

    final prefs = widget.preferences.value;
    if ((prefs.biometricAuthEnabled && AuthProtectionService.isMobile) ||
        prefs.desktopPasswordEnabled) {
      _isLocked = true;
    }

    final cmd = HeaderCommandService.instance;
    cmd.onOpenSend = () {
      if (_accounts.isEmpty) return;
      _send();
    };
    cmd.onOpenReceive = () {
      if (_accounts.isEmpty) return;
      _receive();
    };
    cmd.onOpenStatement = () {
      if (_accounts.isEmpty) return;
      _openStatement();
    };
    cmd.onOpenFinance = () {
      if (_accounts.isEmpty) return;
      _openFinance();
    };
    cmd.onOpenPos = () {
      if (_accounts.isEmpty) return;
      _openPos();
    };
    cmd.onOpenGasTracker = () => _openGasTracker();
    cmd.onOpenPrivacyStealth = () => _openPrivacyStealth();
    cmd.onOpenAddressInspector = () {
      if (_accounts.isEmpty) return;
      _openAddressInspector();
    };
    cmd.onOpenMarket = () => _openMarket();
    cmd.onOpenContacts = () => _openContacts();
    cmd.onOpenAutoDebits = () {
      if (_accounts.isEmpty) return;
      _openAutoDebits();
    };
    cmd.onOpenSettings = () => _openSettings();
    cmd.onToggleHideBalance = () {
      if (mounted) {
        setState(() {
          _hideBalance = !_hideBalance;
          cmd.hideBalanceNotifier.value = _hideBalance;
        });
      }
    };
    cmd.isBalanceHidden = () => _hideBalance;
    cmd.getActiveAccount = () => _accounts.isEmpty ? null : _account;
    cmd.networkLabelNotifier.value = _networkLabel;
    cmd.hideBalanceNotifier.value = _hideBalance;
    cmd.startGasMonitoring();

    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    final cmd = HeaderCommandService.instance;
    cmd.onOpenSend = null;
    cmd.onOpenReceive = null;
    cmd.onOpenStatement = null;
    cmd.onOpenFinance = null;
    cmd.onOpenPos = null;
    cmd.onOpenGasTracker = null;
    cmd.onOpenPrivacyStealth = null;
    cmd.onOpenAddressInspector = null;
    cmd.onOpenMarket = null;
    cmd.onOpenContacts = null;
    cmd.onOpenAutoDebits = null;
    cmd.onOpenSettings = null;
    cmd.onToggleHideBalance = null;
    cmd.isBalanceHidden = null;
    cmd.getActiveAccount = null;
    cmd.stopGasMonitoring();

    WidgetsBinding.instance.removeObserver(this);
    BackgroundSyncService.instance.stop();
    _contacts.dispose();
    _goals.dispose();
    _vaults.dispose();
    _budget.dispose();
    _autoDebits.dispose();
    _groupPurchases.dispose();
    super.dispose();
  }

  /// Aplica as regras de privacidade quando o estado do aplicativo muda.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        widget.preferences.value.hideBalanceInBackground &&
        !_hideBalance) {
      setState(() => _hideBalance = true);
    }
    if ((state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        widget.preferences.value.lockOnBackground) {
      final prefs = widget.preferences.value;
      if (prefs.biometricAuthEnabled || prefs.desktopPasswordEnabled) {
        setState(() => _isLocked = true);
      }
    }
  }

  /// Carrega os dados necessários para apresentar a tela.
  Future<void> _load() async {
    try {
      await _controller.load();
      // A agenda, metas, cofres, orçamento e débitos são opcionais: falhas neles não bloqueiam as carteiras.
      await _contacts.load().catchError((Object _) {});
      await _goals.load().catchError((Object _) {});
      await _vaults.load().catchError((Object _) {});
      await _budget.load().catchError((Object _) {});
      await _autoDebits.load().catchError((Object _) {});
      await _groupPurchases.load().catchError((Object _) {});
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = false;
        cmd.networkLabelNotifier.value = _networkLabel;
        if (_accounts.isNotEmpty) {
          _refreshBalance();
          BackgroundSyncService.instance.start(
            controller: _controller,
            autoDebitController: _autoDebits,
            onBalanceUpdated: () {
              if (mounted) setState(_refreshBalance);
            },
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Atualiza saldo e envios recentes. `force` ignora o cache de saldo
  /// (botão de atualizar e gesto de puxar para atualizar).
  /// Otimizado para evitar chamadas de API duplicadas e múltiplos rebuilds.
  void _refreshBalance({bool force = false}) {
    final revision = ++_balanceRevision;
    _cachedEthBalance = null;
    _cachedBtcBalance = null;
    if (_account.isMultiCoin) {
      _cachedEthBalance = _controller.lastKnownBalanceForSymbol('ETH');
      _cachedBtcBalance = _controller.lastKnownBalanceForSymbol('BTC');

      final ethFuture = _controller.balanceForSymbol('ETH', force: force);
      final btcFuture = _controller.balanceForSymbol('BTC', force: force);

      // O ativo em foco consome o future correspondente sem consulta duplicada
      _balance = _account.activeAsset == 'BTC' ? btcFuture : ethFuture;

      for (final (symbol, future) in [('ETH', ethFuture), ('BTC', btcFuture)]) {
        future.then<void>((value) {
          if (!mounted || revision != _balanceRevision) return;
          final current = symbol == 'ETH'
              ? _cachedEthBalance
              : _cachedBtcBalance;
          if (current == value) return;
          setState(() {
            if (symbol == 'ETH') {
              _cachedEthBalance = value;
            } else {
              _cachedBtcBalance = value;
            }
          });
        }, onError: (Object _) {});
      }
    } else {
      _balance = _controller.balance(force: force);
    }

    _refreshPortfolio(force: force);
    _recent = _controller.history().then(
      (entries) => entries.take(3).toList(),
      onError: (Object _) => const <WalletActivity>[],
    );
  }

  /// Atualiza a taxa de câmbio e o cálculo do patrimônio para a moeda selecionada.
  void _refreshPortfolio({bool force = false}) {
    final currency = _fiatCurrency;
    _exchangeRate = switch (currency.code) {
      'BRL' || 'USD' => Future<double?>.value(1.0),
      final code => FiatExchangeService.instance.rates().then(
        (rates) => rates[code],
      ),
    };
    _portfolioValue = _controller.portfolioValue(
      currency,
      exchangeRate: _exchangeRate,
      force: force,
    );
  }

  /// Força a atualização de saldos, patrimônio e atividade recente.
  Future<void> _pullToRefresh() async {
    if (_accounts.isEmpty || _busy) return;
    setState(() => _refreshBalance(force: true));
    await Future.wait<Object?>([
      _balance.then<Object?>((value) => value, onError: (Object _) => null),
      _portfolioValue,
      _recent,
    ]);
  }

  /// Localiza na agenda o nome do contato associado ao endereço.
  String? _contactName(String address) =>
      _contacts.find(address, _account.bitcoinChain)?.name;

  /// Executa a operação da carteira e encaminha falhas para a interface.
  Future<void> _action(Future<void> Function() action, String error) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FormatException catch (failure) {
      _notify(failure.message);
    } on Exception {
      _notify(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Copia o valor para a área de transferência com limpeza automática de segurança.
  Future<void> _copy(String value, String label) async {
    await ClipboardGuardService.copySensitive(
      context: context,
      text: value,
      label: label,
    );
  }

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> _add(AccountMode mode) => _action(() async {
    final kind = await showDialog<WalletKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolher ativo e rede'),
        children: [
          for (final kind in WalletKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, kind),
              child: Text(kind.label),
            ),
        ],
      ),
    );
    if (!mounted || kind == null) return;
    final bitcoin = kind.bitcoin;
    final account = await showDialog<WalletAccount>(
      context: context,
      builder: (_) => WalletForm(
        title: mode.label,
        description: kind.label,
        action: 'Salvar carteira',
        fields: [
          (label: 'Nome da carteira', secret: false, amount: false),
          (label: 'Nome de usuário (@usuario)', secret: false, amount: false),
          if (mode == AccountMode.import)
            (
              label: kind.isMulti
                  ? 'Chave privada hexadecimal (64 caracteres)'
                  : (bitcoin == null
                        ? 'Chave privada hexadecimal'
                        : 'Chave privada WIF comprimida'),
              secret: true,
              amount: false,
            ),
          if (mode == AccountMode.watch)
            (label: 'Endereço público', secret: false, amount: false),
        ],
        submit: (values) {
          final name = values[0].trim();
          final usernameInput = values[1].trim();
          if (name.isEmpty || name.length > 40) {
            throw const FormatException('Use um nome de 1 a 40 caracteres.');
          }
          if (usernameInput.isEmpty || usernameInput.length < 3) {
            throw const FormatException(
              'Escolha um nome de usuário com pelo menos 3 caracteres.',
            );
          }
          final username = WalletAccount.sanitizeUsername(usernameInput);
          if (kind.isMulti) {
            final btcChain = kind.bitcoin ?? BitcoinChain.testnet4;
            return switch (mode) {
              AccountMode.create => WalletAccount.createMultiCoin(
                name,
                username: username,
                bitcoin: btcChain,
              ),
              AccountMode.import => WalletAccount.importMultiCoin(
                name,
                values[2],
                username: username,
                bitcoin: btcChain,
              ),
              AccountMode.watch => WalletAccount.watch(
                name,
                values[2],
                username: username,
                bitcoin: bitcoin,
              ),
            };
          }
          return switch (mode) {
            AccountMode.create => WalletAccount.create(
              name,
              username: username,
              bitcoin: bitcoin,
            ),
            AccountMode.import => WalletAccount.import(
              name,
              values[2],
              username: username,
              bitcoin: bitcoin,
            ),
            AccountMode.watch => WalletAccount.watch(
              name,
              values[2],
              username: username,
              bitcoin: bitcoin,
            ),
          };
        },
      ),
    );
    if (!mounted || account == null) return;
    await _saveAccount(
      account,
      isNewAccount: mode == AccountMode.create || mode == AccountMode.import,
    );
  }, 'Não foi possível salvar a carteira no armazenamento seguro.');

  /// Salva a carteira e atualiza a seleção e o saldo na tela.
  Future<void> _saveAccount(
    WalletAccount account, {
    bool isNewAccount = false,
  }) async {
    await _controller.add(account);
    if (mounted) {
      setState(_refreshBalance);
      BackgroundSyncService.instance.start(
        controller: _controller,
        autoDebitController: _autoDebits,
        onBalanceUpdated: () {
          if (mounted) setState(_refreshBalance);
        },
      );
      if (isNewAccount) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => WelcomeOnboardingScreen(accountName: account.name),
          ),
        );
      }
    }
  }

  /// Abre a importação de carteiras por código QR.
  Future<void> _importQr({bool isMirror = false}) => _action(() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletImportPage(initialMirror: isMirror),
      ),
    );
    if (!mounted || result == null) return;

    if (result is SyncPackageResult) {
      if (result.isMirror || result.accounts.length > 1) {
        final count = await _controller.addAll(result.accounts);
        setState(_refreshBalance);
        _notify(
          result.isMirror
              ? '$count ${count == 1 ? "conta espelhada" : "contas espelhadas"} em modo observador.'
              : '$count ${count == 1 ? "conta importada" : "contas importadas"}.',
        );
      } else if (result.accounts.isNotEmpty) {
        await _saveAccount(result.accounts.first, isNewAccount: true);
        _notify('Carteira importada.');
      }
    } else if (result is WalletAccount) {
      await _saveAccount(result, isNewAccount: true);
      _notify('Carteira importada.');
    }
  }, 'Não foi possível salvar as contas.');

  /// Abre a exportação de carteiras por código QR.
  Future<void> _exportQr({bool isMirror = false}) => _action(() async {
    if (!mounted || _accounts.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => WalletExportDialog(
        account: _account,
        accounts: _accounts,
        initialIsMirror: isMirror,
      ),
    );
  }, 'Não foi possível abrir a sincronização de contas.');

  /// Abre as opções de recebimento da carteira selecionada.
  Future<void> _receive() async {
    if (_busy || _accounts.isEmpty) return;
    await CryptoReceiveQrSheet.show(
      context,
      account: _account,
      network: _network,
    );
  }

  /// Abre o fluxo de envio para a carteira selecionada.
  Future<void> _send({
    bool purchase = false,
    String? initialAddress,
  }) => _action(() async {
    if (_accounts.isEmpty) return;
    final account = _account;
    final network = _network;
    final bitcoin = account.bitcoinChain;
    final symbol = account.symbol;
    final draft = await showDialog<({Payment payment, String? name})>(
      context: context,
      builder: (_) => WalletForm(
        title: purchase ? 'Nova compra em $symbol' : 'Enviar $symbol',
        description: _networkLabel,
        action: 'Continuar',
        initialText: initialAddress,
        fields: [
          (
            label: 'Endereço ou link de pagamento',
            secret: false,
            amount: false,
          ),
          (label: 'Valor em $symbol', secret: false, amount: true),
          (
            label: purchase ? 'Produto, serviço ou referência da compra' : 'Tipo de pagamento (ex: Compra, Serviço, Aluguel, Pessoal...)',
            secret: false,
            amount: false,
          ),
        ],
        suggestions: {
          2: purchase
              ? ['Produto', 'Serviço', 'Assinatura', 'Ingresso']
              : [
                  'Compra',
                  'Serviço',
                  'Aluguel',
                  'Pessoal',
                  'Investimento',
                  'Doação',
                ],
        },
        paymentQr: true,
        contacts: [
          for (final contact in _contacts.compatibleWith(bitcoin))
            (name: contact.name, address: contact.address),
        ],
        submit: (values) {
          final type = values[2].trim();
          if (type.length > 80) {
            throw const FormatException(
              'Use até 80 caracteres para identificar o tipo de pagamento.',
            );
          }
          return (
            name: type.isEmpty ? (purchase ? 'Compra' : null) : type,
            payment: parsePayment(
              values[0],
              values[1],
              ethereum: network,
              bitcoin: bitcoin,
            ),
          );
        },
      ),
    );
    if (!mounted || draft == null) return;
    final transfer = draft.payment;
    if (!account.canSign) {
      final opened = await launchUrl(
        Uri.parse(_paymentRequest(transfer.to, transfer.amount)),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _notify(
          'Nenhuma carteira compatível foi encontrada neste dispositivo.',
        );
      }
      return;
    }

    final prepared = await _controller.prepare(
      transfer,
      purchaseName: draft.name,
      paymentType: draft.name,
    );
    try {
      final fee = prepared.fee;
      if (!mounted) return;
      final recipientUser = _contactName(transfer.to);
      final targetEmojis = SecurityShieldService.visualEmojis(transfer.to);
      final myEmojis = SecurityShieldService.visualEmojis(
        account.publicAddress,
      );
      final knownAddresses = _contacts.value.map((c) => c.address).toList();
      final hasPoisonRisk = SecurityShieldService.isPoisoningRisk(
        targetAddress: transfer.to,
        knownAddresses: knownAddresses,
      );

      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            purchase
                ? 'Confirmar pagamento da compra'
                : 'Confirmar envio seguro',
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              'Rede: $_networkLabel\n\n'
              '${draft.name == null ? '' : 'Tipo de pagamento: ${draft.name}\n\n'}'
              '• REMETENTE:\n'
              'Usuário: ${account.name} (${account.username})\n'
              'ID Soberano: ${account.uniqueId}\n'
              'Emojis de Segurança: $myEmojis\n'
              'Chave Pública: ${account.publicAddress}\n\n'
              '• DESTINATÁRIO (QUEM VAI RECEBER):\n'
              'Usuário / Contato: ${recipientUser ?? "Usuário Externo On-Chain"}\n'
              '🛡️ Emojis de Conferência: $targetEmojis\n'
              'Chave Pública de Destino: ${transfer.to}\n\n'
              '${hasPoisonRisk ? "⚠️ ALERTA ANTI-GOLPE: Risco de Address Poisoning detectado! Este endereço tem início e fim parecidos com um contato salvo, mas é DIFERENTE. Confira os emojis com o recebedor antes de enviar!\n\n" : ""}'
              '• VALORES:\n'
              'Valor: ${_formatAmount(transfer.amount)} $symbol\n'
              'Taxa máxima: ${_formatAmount(fee)} $symbol\n'
              'Total máximo: ${_formatAmount(transfer.amount + fee)} $symbol',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar e Enviar'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final result = await prepared.send();
      if (!mounted) return;
      setState(_refreshBalance);
      final known = _contacts.find(transfer.to, bitcoin) != null;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            result.accepted
                ? 'Enviada à rede'
                : 'Envio sem confirmação do servidor',
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              '${result.accepted ? 'Acompanhe a inclusão da transação na rede.' : 'Consulte o hash no explorador antes de tentar outro envio.'}\n\n${result.hash}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            if (!known)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveContact(transfer.to, bitcoin);
                },
                child: const Text('Salvar contato'),
              ),
            TextButton(
              onPressed: () => _copy(result.hash, 'Hash'),
              child: const Text('Copiar hash'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final opened = await launchUrl(
                    bitcoin?.explorer(result.hash) ??
                        Uri.https(network.explorer, '/tx/${result.hash}'),
                  );
                  if (!opened) _notify('Não foi possível abrir o explorador.');
                } on Exception {
                  _notify('Não foi possível abrir o explorador.');
                }
              },
              child: const Text('Explorador'),
            ),
          ],
        ),
      );
    } finally {
      await prepared.close();
    }
  }, 'Não foi possível preparar o envio. Verifique a rede e o saldo.');

  /// Salva o contato.
  Future<void> _saveContact(String address, BitcoinChain? bitcoin) async {
    final contact = await showDialog<WalletContact>(
      context: context,
      builder: (_) => WalletForm(
        title: 'Salvar contato',
        description: address,
        action: 'Salvar',
        fields: const [(label: 'Nome', secret: false, amount: false)],
        submit: (values) =>
            WalletContact.parse(values.single, address, bitcoin: bitcoin),
      ),
    );
    if (!mounted || contact == null) return;
    try {
      await _contacts.add(contact);
      if (mounted) setState(_refreshBalance);
      _notify('Contato salvo.');
    } on FormatException catch (failure) {
      _notify(failure.message);
    } on Exception {
      _notify('Não foi possível salvar o contato.');
    }
  }

  /// Abre os contatos.
  Future<void> _openContacts() async {
    if (_busy) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletContactsScreen(
          contacts: _contacts,
          account: _account,
          network: _network,
          groupPurchases: _groupPurchases,
          onSendToContact: (contact, asset) async {
            if (_account.isMultiCoin && _account.activeAsset != asset) {
              await _controller.setActiveAsset(asset);
              setState(_refreshBalance);
            }
            final targetAddr = contact.addressFor(_account.bitcoinChain);
            _send(initialAddress: targetAddr);
          },
        ),
      ),
    );
    // Nomes podem ter mudado: atualiza a lista de recentes.
    if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
  }

  /// Consulta o histórico conforme os filtros e a paginação recebidos.
  Future<void> _history({bool purchases = false}) async {
    var create = false;
    await _action(() async {
      final account = _account;
      final bitcoin = account.bitcoinChain;
      final entries = await _controller.history();
      if (!mounted) return;
      create =
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => WalletActivityScreen(
                entries: purchases
                    ? entries
                          .where((entry) => entry.purchaseName != null)
                          .toList()
                    : entries,
                purchases: purchases,
                canPurchase: account.canSign,
                network: _networkLabel,
                contactName: _contactName,
                addressExplorer: bitcoin == null
                    ? Uri.https(
                        _network.explorer,
                        '/address/${account.publicAddress}',
                      )
                    : Uri.https(
                        'blockstream.info',
                        '${bitcoin.path}/address/${account.publicAddress}',
                      ),
              ),
            ),
          ) ??
          false;
    }, 'Não foi possível abrir o histórico.');
    if (mounted && create) await _send(purchase: true);
  }

  /// Abre o extrato.
  Future<void> _openStatement() async {
    if (_busy || _accounts.isEmpty) return;
    final account = _account;
    final bitcoin = account.bitcoinChain;
    final addressExplorer = bitcoin == null
        ? Uri.https(_network.explorer, '/address/${account.publicAddress}')
        : Uri.https(
            'blockstream.info',
            '${bitcoin.path}/address/${account.publicAddress}',
          );

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletStatementScreen(
          account: account,
          network: _network,
          statement: _controller.statement(),
          contacts: _contacts,
          addressExplorer: addressExplorer,
        ),
      ),
    );
    if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
  }

  /// Abre as ferramentas financeiras.
  Future<void> _openFinance() async {
    if (_busy || _accounts.isEmpty) return;
    final balance = _controller.lastKnownBalance() ?? BigInt.zero;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletFinanceScreen(
          account: _account,
          balance: balance,
          goals: _goals,
          vaults: _vaults,
          budget: _budget,
          autoDebits: _autoDebits,
          walletController: _controller,
          contacts: _contacts,
          groupPurchases: _groupPurchases,
        ),
      ),
    );
    if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
  }

  /// Abre os débitos automáticos.
  Future<void> _openAutoDebits() async {
    if (_busy || _accounts.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletAutoDebitScreen(
          account: _account,
          autoDebits: _autoDebits,
          walletController: _controller,
        ),
      ),
    );
    if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
  }

  /// Abre o mercado.
  Future<void> _openMarket() async {
    if (_busy) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CryptoMarketScreen()),
    );
  }

  /// Abre o ponto de venda para criar uma cobrança com cálculo de equivalência em criptomoeda.
  Future<void> _openPos() async {
    if (_busy || _accounts.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CryptoPosScreen(
          account: _account,
          baseCurrency: _fiatCurrency,
        ),
      ),
    );
  }

  /// Abre o monitor de gas.
  Future<void> _openGasTracker() async {
    if (_busy) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const GasTrackerScreen()),
    );
  }

  /// Abre `privacy stealth` no fluxo de painel.
  Future<void> _openPrivacyStealth() async {
    if (_busy || _accounts.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacyStealthScreen(
          account: _account,
          hasBiometrics: widget.preferences.value.biometricAuthEnabled,
          lockOnBackground: widget.preferences.value.lockOnBackground,
          onStealthModeChanged: (val) {
            setState(() {
              _hideBalance = val;
            });
          },
        ),
      ),
    );
  }

  /// Abre o inspetor de endereços.
  Future<void> _openAddressInspector() async {
    if (_busy || _accounts.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          AddressInspectorDialog(account: _account, contacts: _contacts),
    );
  }

  /// Salva o novo nome da carteira selecionada.
  Future<void> _rename() => _action(() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => WalletForm(
        title: 'Renomear carteira',
        action: 'Salvar',
        initialText: _account.name,
        fields: const [
          (label: 'Nome da carteira', secret: false, amount: false),
        ],
        submit: (values) {
          final name = values.single.trim();
          if (name.isEmpty || name.length > 40) {
            throw const FormatException('Use um nome de 1 a 40 caracteres.');
          }
          return name;
        },
      ),
    );
    if (!mounted || name == null || name == _account.name) return;
    await _controller.rename(name);
    if (mounted) setState(() {});
  }, 'Não foi possível renomear a carteira.');

  /// Abre `account management` no fluxo de painel.
  Future<void> _openAccountManagement() async {
    if (_busy || _accounts.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletAccountScreen(
          account: _account,
          controller: _controller,
          onAccountUpdated: () {
            if (mounted) setState(_refreshBalance);
          },
          onBackupRequested: _backup,
          onExportQrRequested: _exportQr,
          onRemoveRequested: _remove,
        ),
      ),
    );
    if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
  }

  /// Abre as configurações.
  Future<void> _openSettings() async {
    if (_busy || _settingsOpen) return;
    _settingsOpen = true;
    final account = _accounts.isEmpty ? null : _account;
    final SettingsAction? action;
    try {
      action = await Navigator.push<SettingsAction>(
        context,
        MaterialPageRoute(
          builder: (_) => WalletSettingsScreen(
            preferences: widget.preferences,
            save: (preferences) async {
              final changed =
                  preferences.fiatCurrency.code != _fiatCurrency.code;
              await widget.savePreferences(preferences);
              if (mounted && changed && _accounts.isNotEmpty) {
                setState(_refreshPortfolio);
              }
            },
            walletName: account?.name,
            canSign: account?.canSign ?? false,
            canManageWallets: !_loading && !_loadFailed,
            walletAccount: account,
            walletController: _controller,
            onAccountUpdated: () {
              if (mounted) setState(_refreshBalance);
            },
          ),
        ),
      );
    } finally {
      _settingsOpen = false;
    }
    if (!mounted || action == null) return;
    await switch (action) {
      SettingsAction.create => _add(AccountMode.create),
      SettingsAction.importKey => _add(AccountMode.import),
      SettingsAction.watch => _add(AccountMode.watch),
      SettingsAction.rename => _rename(),
      SettingsAction.backup => _backup(),
      SettingsAction.exportQr => _exportQr(),
      SettingsAction.importQr => _importQr(isMirror: false),
      SettingsAction.mirrorAccounts => _importQr(isMirror: true),
      SettingsAction.history => _history(),
      SettingsAction.statement => _openStatement(),
      SettingsAction.finance => _openFinance(),
      SettingsAction.market => _openMarket(),
      SettingsAction.pos => _openPos(),
      SettingsAction.inspector => _openAddressInspector(),
      SettingsAction.gasTracker => _openGasTracker(),
      SettingsAction.privacyStealth => _openPrivacyStealth(),
      SettingsAction.autoDebit => _openAutoDebits(),
      SettingsAction.manageAccount => _openAccountManagement(),
      SettingsAction.contacts => _openContacts(),
      SettingsAction.remove => _remove(),
    };
  }

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> _remove() => _action(() async {
    final account = _account;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => WalletForm(
        title: 'Remover carteira deste aparelho?',
        description: account.canSign
            ? 'A chave privada de “${account.name}” será apagada deste aparelho. Verifique seu backup antes de continuar.'
            : 'A carteira “${account.name}” será removida da lista deste aparelho.',
        action: 'Remover carteira',
        destructive: true,
        fields: const [
          (label: 'Digite o nome da carteira', secret: false, amount: false),
        ],
        submit: (values) {
          if (values.single.trim() != account.name) {
            throw const FormatException(
              'Digite o nome exato da carteira para confirmar.',
            );
          }
          return true;
        },
      ),
    );
    if (!mounted || confirmed != true) return;
    await _controller.remove();
    if (!mounted) return;
    setState(() {
      if (_accounts.isNotEmpty) _refreshBalance();
    });
    _notify('Carteira removida deste aparelho.');
  }, 'Não foi possível remover a carteira.');

  /// Abre o fluxo de cópia de segurança.
  Future<void> _backup() => _action(() async {
    final reveal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mostrar chave de recuperação?'),
        content: const Text(
          'Qualquer pessoa com esta chave pode movimentar os fundos. Guarde uma cópia em local seguro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mostrar chave'),
          ),
        ],
      ),
    );
    if (!mounted || reveal != true) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chave privada'),
        content: SelectableText(
          _account.bitcoinChain == null
              ? '0x${_account.secret}'
              : _account.secret!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
  }, 'Não foi possível mostrar a chave.');

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return AppLockScreen(
        isDesktopLock: AuthProtectionService.isDesktop,
        onUnlocked: () => setState(() => _isLocked = false),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SafeArea(
              top: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadFailed
                  ? _storageError()
                  : LayoutBuilder(
                      builder: (context, viewport) => RefreshIndicator(
                        onRefresh: _pullToRefresh,
                        notificationPredicate: (_) => _accounts.isNotEmpty,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            viewport.maxWidth >= 680 ? 32 : 16,
                            viewport.maxWidth >= 680 ? 30 : 20,
                            viewport.maxWidth >= 680 ? 32 : 16,
                            32,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: SizedBox(
                                width: double.infinity,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _accounts.isEmpty
                                      ? _welcome()
                                      : _dashboard(viewport.maxWidth),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Monta o cabeçalho com o estado atual.
  Widget _header() => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideDesktop = constraints.maxWidth >= 840;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/wallet_icon.png',
                                width: isWideDesktop ? 38 : 32,
                                height: isWideDesktop ? 38 : 32,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Private Wallet',
                              style: TextStyle(
                                fontSize: isWideDesktop ? 19 : 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_accounts.isNotEmpty && !_loading) ...[
                              const SizedBox(width: 8),
                              _networkBadge(),
                            ],
                            const Spacer(),
                            if (isWideDesktop &&
                                !_loading &&
                                !_loadFailed &&
                                _accounts.isNotEmpty) ...[
                              TextButton.icon(
                                onPressed: _busy ? null : _openStatement,
                                icon: const Icon(Icons.list_alt_rounded, size: 18),
                                label: Text(context.l10n.statementTitle),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _busy ? null : _openFinance,
                                icon: const Icon(Icons.insights_rounded, size: 18),
                                label: Text(context.l10n.financeTitle),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _busy ? null : _openAutoDebits,
                                icon: const Icon(Icons.autorenew, size: 18),
                                label: Text(context.l10n.autoDebitTitle),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: _busy ? null : _openContacts,
                                icon: const Icon(Icons.contacts_outlined, size: 18),
                                label: Text(context.l10n.contactsTitle),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: context.l10n.refresh,
                                onPressed: _busy ? null : _pullToRefresh,
                                icon: Icon(Icons.refresh, color: _colors.primary),
                              ),
                              const SizedBox(width: 4),
                            ] else if (!isWideDesktop && !_loading && !_loadFailed) ...[
                              // Monitor Rápido de Gas no topo do Mobile
                              ValueListenableBuilder<GasFeeInfo?>(
                                valueListenable: HeaderCommandService.instance.gasInfoNotifier,
                                builder: (context, info, _) {
                                  final gwei = info?.ethNormalGwei ?? 24;
                                  return Tooltip(
                                    message: 'Taxa de Gas estimada: $gwei Gwei. Toque para abrir o Monitor de Gas.',
                                    child: InkWell(
                                      onTap: _busy ? null : _openGasTracker,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                        margin: const EdgeInsets.only(right: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.deepOrange.withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.speed, size: 12, color: Colors.deepOrange),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$gwei Gwei',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Botão rápido de pesquisa no app bar
                              IconButton(
                                tooltip: 'Buscar ferramentas e ações',
                                onPressed: () => HeaderQuickSearchDialog.show(context),
                                icon: Icon(Icons.search_rounded, color: _colors.primary),
                              ),
                            ],
                            if (!_loading && !_loadFailed)
                              PopupMenuButton<String>(
                                enabled: !_busy,
                                tooltip: 'Mais opções e ferramentas',
                                icon: Icon(Icons.more_vert, color: _colors.primary),
                                onSelected: (action) {
                                  switch (action) {
                                    case 'import':
                                      _importQr(isMirror: false);
                                    case 'mirror':
                                      _importQr(isMirror: true);
                                    case 'export':
                                      _exportQr();
                                    case 'market':
                                      _openMarket();
                                    case 'pos':
                                      _openPos();
                                    case 'inspector':
                                      _openAddressInspector();
                                    case 'gasTracker':
                                      _openGasTracker();
                                    case 'privacyStealth':
                                      _openPrivacyStealth();
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'market',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.trending_up,
                                          size: 20,
                                          color: Color(0xFFF7931A),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Mercado & Alertas'),
                                      ],
                                    ),
                                  ),
                                  if (_accounts.isNotEmpty) ...[
                                    const PopupMenuItem(
                                      value: 'pos',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.point_of_sale_outlined,
                                            size: 20,
                                            color: Color(0xFF627EEA),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Cobrança & PDV'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'inspector',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.security,
                                            size: 20,
                                            color: Colors.blueAccent,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Inspetor Anti-Golpe'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'gasTracker',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.speed,
                                            size: 20,
                                            color: Colors.deepOrange,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Otimizador de Gas'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'privacyStealth',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 20,
                                            color: Colors.purple,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Privacidade & Camuflagem'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                  ],
                                  const PopupMenuItem(
                                    value: 'import',
                                    child: Row(
                                      children: [
                                        Icon(Icons.download_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Importar carteira'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'mirror',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy_all_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Espelhar contas'),
                                      ],
                                    ),
                                  ),
                                  if (_accounts.isNotEmpty)
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Row(
                                        children: [
                                          Icon(Icons.qr_code_2, size: 20),
                                          SizedBox(width: 10),
                                          Text('Sincronizar / Exportar'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            IconButton(
                              tooltip: context.l10n.settingsTitle,
                              onPressed: _busy ? null : _openSettings,
                              icon: Icon(
                                Icons.settings_outlined,
                                color: _colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (_busy)
            const LinearProgressIndicator(minHeight: 2)
          else
            Divider(
              height: 1,
              thickness: 1,
              color: _colors.outlineVariant.withValues(alpha: 0.25),
            ),
        ],
      ),
    ),
  );

  /// Informa a falha de armazenamento na interface.
  Widget _storageError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: WalletPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 30, color: _colors.primary),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível abrir o armazenamento seguro.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );

  /// Monta a tela inicial exibida antes do cadastro da primeira carteira.
  Widget _welcome() {
    final l10n = context.l10n;
    final intro = BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkBadge(l10n.selfCustodyBadge, isTest: false),
          const SizedBox(height: 22),
          Text(
            l10n.yourFirstWallet,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.welcomeDescription,
            style: const TextStyle(
              color: walletHeroMuted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [AssetMark('ETH'), AssetMark('BTC')],
          ),
        ],
      ),
    );
    final setup = WalletPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WalletSectionTitle(l10n.addAWallet),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _add(AccountMode.create),
            icon: const Icon(Icons.add),
            label: Text(l10n.createWallet),
          ),
          const SizedBox(height: 8),
          for (final mode in [AccountMode.import, AccountMode.watch])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(mode.icon, color: _colors.primary),
              title: Text(mode.localizedLabel(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _add(mode),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.download_rounded, color: _colors.primary),
            title: Text(l10n.importQr),
            subtitle: const Text('Com chave privada para envio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _importQr(isMirror: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_all_rounded, color: _colors.primary),
            title: const Text('Adicionar cold wallet por QR'),
            subtitle: const Text('Modo observador seguro (somente leitura)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _importQr(isMirror: true),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 760
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: intro),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: setup),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [intro, const SizedBox(height: 16), setup],
            ),
    );
  }

  /// Monta o painel principal com o estado atual.
  Widget _dashboard(double width) {
    final isDesktop = width >= 1080;
    final isTablet = width >= 720 && width < 1080;

    return Column(
      key: const ValueKey('dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Início',
          style: TextStyle(
            fontSize: isDesktop ? 34 : (isTablet ? 28 : 26),
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Seu dinheiro seguro e sob o seu controle total.',
          style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 18),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna 1: Saldo, Moedas & Minhas Carteiras
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _balanceCard(),
                    const SizedBox(height: 18),
                    _assetsOverview(),
                    const SizedBox(height: 18),
                    _walletsPanel(),
                    const SizedBox(height: 18),
                    _securityPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Coluna 2: Serviços, Guardar Dinheiro & Endereços
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _autoDebitReminder(),
                    _modernServicesGrid(),
                    const SizedBox(height: 18),
                    _vaultsSummaryPanel(),
                    const SizedBox(height: 18),
                    _detailsPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Coluna 3: Últimas Movimentações
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_recentPanel()],
                ),
              ),
            ],
          )
        else if (isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna 1 do Tablet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _balanceCard(),
                    const SizedBox(height: 16),
                    _assetsOverview(),
                    const SizedBox(height: 16),
                    _autoDebitReminder(),
                    _modernServicesGrid(),
                    const SizedBox(height: 16),
                    _vaultsSummaryPanel(),
                    const SizedBox(height: 16),
                    _detailsPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Coluna 2 do Tablet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _walletsPanel(),
                    const SizedBox(height: 16),
                    _recentPanel(),
                    const SizedBox(height: 16),
                    _securityPanel(),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _balanceCard(),
          const SizedBox(height: 16),
          _assetsOverview(),
          const SizedBox(height: 16),
          _autoDebitReminder(),
          _modernServicesGrid(),
          const SizedBox(height: 16),
          _vaultsSummaryPanel(),
          const SizedBox(height: 16),
          _walletsPanel(),
          const SizedBox(height: 16),
          _recentPanel(),
          const SizedBox(height: 16),
          _detailsPanel(),
          const SizedBox(height: 16),
          _securityPanel(),
        ],
      ],
    );
  }

  /// Visão geral limpa dos saldos de cada moeda com seleção rápida.
  Widget _assetsOverview() {
    final btcAmount = _account.isMultiCoin
        ? (_cachedBtcBalance ?? _controller.lastKnownBalanceForSymbol('BTC'))
        : (_account.bitcoinChain != null ? _controller.lastKnownBalance() : null);
    final ethAmount = _account.isMultiCoin
        ? (_cachedEthBalance ?? _controller.lastKnownBalanceForSymbol('ETH'))
        : (_account.bitcoinChain == null ? _controller.lastKnownBalance() : null);

    final isMulti = _account.isMultiCoin;
    final isBtcActive = _account.activeAsset == 'BTC';

    return WalletPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WalletSectionTitle(
            'Suas Moedas',
            trailing: isMulti
                ? Text(
                    'Toque para alternar',
                    style: TextStyle(
                      fontSize: 12,
                      color: _colors.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;
              final btcCard = _coinCard(
                symbol: 'BTC',
                name: 'Bitcoin',
                amountText: _hideBalance
                    ? '••••'
                    : (btcAmount == null ? '...' : '${formatBtc(btcAmount)} BTC'),
                isActive: isMulti ? isBtcActive : _account.bitcoinChain != null,
                onTap: isMulti
                    ? () async {
                        await _controller.setActiveAsset('BTC');
                        if (mounted) setState(_refreshBalance);
                      }
                    : null,
              );

              final ethCard = _coinCard(
                symbol: 'ETH',
                name: 'Ethereum',
                amountText: _hideBalance
                    ? '••••'
                    : (ethAmount == null ? '...' : '${formatEth(ethAmount)} ETH'),
                isActive: isMulti ? !isBtcActive : _account.bitcoinChain == null,
                onTap: isMulti
                    ? () async {
                        await _controller.setActiveAsset('ETH');
                        if (mounted) setState(_refreshBalance);
                      }
                    : null,
              );

              if (isNarrow) {
                return Column(
                  children: [
                    btcCard,
                    const SizedBox(height: 8),
                    ethCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: btcCard),
                  const SizedBox(width: 10),
                  Expanded(child: ethCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _coinCard({
    required String symbol,
    required String name,
    required String amountText,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive
          ? _colors.primaryContainer.withValues(alpha: 0.35)
          : _colors.surfaceContainerHighest.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? _colors.primary.withValues(alpha: 0.5)
                  : _colors.outlineVariant.withValues(alpha: 0.25),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              AssetMark(symbol, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _colors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Em uso',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grade moderna e limpa de serviços e facilidades, sem jargões técnicos.
  Widget _modernServicesGrid() {
    final services = [
      _ServiceItem(
        icon: Icons.qr_code_rounded,
        color: const Color(0xFF627EEA),
        title: 'Cobrar com QR',
        subtitle: 'Cobre no balcão ou na mesa',
        onTap: _openPos,
      ),
      _ServiceItem(
        icon: Icons.savings_outlined,
        color: Colors.teal,
        title: 'Guardar Dinheiro',
        subtitle: 'Cofres e metas sem taxas',
        onTap: _openFinance,
      ),
      _ServiceItem(
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFF7931A),
        title: 'Cotações de Hoje',
        subtitle: 'Preços ao vivo e alertas',
        onTap: _openMarket,
      ),
      _ServiceItem(
        icon: Icons.speed_rounded,
        color: Colors.deepOrange,
        title: 'Taxas de Envio',
        subtitle: 'Melhor horário para transferir',
        onTap: _openGasTracker,
      ),
      _ServiceItem(
        icon: Icons.verified_user_outlined,
        color: Colors.blueAccent,
        title: 'Checar Endereço',
        subtitle: 'Verifique antes de transferir',
        onTap: _openAddressInspector,
      ),
      _ServiceItem(
        icon: Icons.update_rounded,
        color: Colors.indigoAccent,
        title: 'Pagamentos Automáticos',
        subtitle: 'Lembretes e transferências',
        onTap: _openAutoDebits,
      ),
      _ServiceItem(
        icon: Icons.people_outline_rounded,
        color: Colors.cyan,
        title: 'Amigos & Contatos',
        subtitle: 'Contatos e chaves salvas',
        onTap: _openContacts,
      ),
      _ServiceItem(
        icon: Icons.copy_rounded,
        color: Colors.purple,
        title: 'Copiar Endereço',
        subtitle: 'Compartilhe para receber',
        onTap: () => _copy(_account.currentAddress, 'Endereço'),
      ),
    ];

    return WalletPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WalletSectionTitle('Serviços & Facilidades'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 340;
              final crossAxisCount = isVeryNarrow ? 1 : 2;
              const spacing = 8.0;
              final width =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                      crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final s in services)
                    SizedBox(
                      width: width,
                      child: _serviceCard(s),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(_ServiceItem item) {
    return Material(
      color: item.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _busy ? null : item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.color.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: _colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lembra sobre os planos ativos e permite revisar ou desativar cada um.
  Widget _autoDebitReminder() => ValueListenableBuilder<List<AutoDebitPlan>>(
    valueListenable: _autoDebits,
    builder: (context, _, child) {
      final plans = _autoDebits.activePlans(_account.publicAddress);
      if (plans.isEmpty) return const SizedBox.shrink();
      plans.sort((a, b) => a.nextExecution.compareTo(b.nextExecution));
      final next = plans.first;
      final date = MaterialLocalizations.of(context)
          .formatShortDate(next.nextExecution.toLocal());
      final schedule = next.isDue
          ? context.l10n.overduePayment
          : context.l10n.nextDebit(date);
      final automatic = plans.any((plan) => plan.autoExecution);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          margin: EdgeInsets.zero,
          color: _colors.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(context.l10n.activeDebits(plans.length)),
            subtitle: Text(
              '$schedule ${automatic ? context.l10n.automaticSendingEnabled : context.l10n.manualConfirmationRequired}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _openAutoDebits,
          ),
        ),
      );
    },
  );

  /// Monta o histórico recente com o estado atual.
  Widget _recentPanel() => WalletPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletSectionTitle(
          'Últimas Movimentações',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _openStatement,
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: Text(context.l10n.statementTitle),
              ),
              TextButton(
                onPressed: _busy ? null : _history,
                child: Text(context.l10n.viewAll),
              ),
            ],
          ),
        ),
        FutureBuilder<List<WalletActivity>>(
          future: _recent,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LinearProgressIndicator(),
              );
            }
            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma movimentação realizada ainda.',
                  style: TextStyle(color: _colors.onSurfaceVariant),
                ),
              );
            }
            return Column(
              children: [
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _colors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _contactName(entry.recipient) ??
                          shortAddress(entry.recipient),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${dayLabel(entry.created)} · ${timeLabel(entry.created)}',
                      style: TextStyle(color: _colors.onSurfaceVariant),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hideBalance
                              ? '••••'
                              : '−${entry.format(entry.amount)} ${entry.symbol}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.receipt_long, size: 18),
                          tooltip: 'Comprovante',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => showCryptoReceipt(
                            context: context,
                            activity: entry,
                            ethereumNetwork: _account.bitcoinChain == null
                                ? _network
                                : null,
                            bitcoinChain: _account.bitcoinChain,
                            fromAddress: _account.publicAddress,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  /// Monta o seletor visual da rede usada pela carteira.
  Widget _networkBadge() {
    final bitcoin = _account.bitcoinChain;
    final badge = NetworkBadge(
      _networkLabel,
      isTest: bitcoin == null
          ? _network == Network.sepolia
          : bitcoin == BitcoinChain.testnet4,
    );
    if (bitcoin != null) return badge;
    return PopupMenuButton<Network>(
      enabled: !_busy,
      tooltip: 'Selecionar rede Ethereum',
      initialValue: _network,
      onSelected: (network) {
        if (network == _network) return;
        setState(() {
          _controller.network = network;
          HeaderCommandService.instance.networkLabelNotifier.value = network.label;
          _refreshBalance();
        });
      },
      itemBuilder: (_) => [
        for (final network in Network.values)
          PopupMenuItem(value: network, child: Text(network.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: badge),
            const Icon(Icons.expand_more, color: walletHeroMuted, size: 18),
          ],
        ),
      ),
    );
  }

  /// Monta o cartão de saldo com o estado atual.
  Widget _balanceCard() => FutureBuilder<BigInt>(
    future: _balance,
    builder: (context, snapshot) {
      final isSyncing = snapshot.connectionState != ConnectionState.done;
      final activeAmount =
          (isSyncing ? null : snapshot.data) ?? _controller.lastKnownBalance();

      return FutureBuilder<double?>(
        future: _exchangeRate,
        builder: (context, exchange) => MultiCoinBalanceCard(
          account: _account,
          network: _network,
          fiatCurrency: _fiatCurrency,
          exchangeRate: exchange.connectionState == ConnectionState.done
              ? exchange.data
              : null,
          ethBalance: _account.isMultiCoin
              ? (_cachedEthBalance ??
                    _controller.lastKnownBalanceForSymbol('ETH'))
              : (_account.bitcoinChain == null ? activeAmount : null),
          btcBalance: _account.isMultiCoin
              ? (_cachedBtcBalance ??
                    _controller.lastKnownBalanceForSymbol('BTC'))
              : (_account.bitcoinChain != null ? activeAmount : null),
          activeBalance: activeAmount,
          hideBalance: _hideBalance,
          isSyncing: isSyncing,
          networkBadge: _networkBadge(),
          onToggleHideBalance: () => setState(() {
            _hideBalance = !_hideBalance;
            HeaderCommandService.instance.hideBalanceNotifier.value = _hideBalance;
          }),
          onSelectAsset: (asset) async {
            await _controller.setActiveAsset(asset);
            if (mounted && _accounts.isNotEmpty) setState(_refreshBalance);
          },
          onSend: _busy ? null : _send,
          onReceive: _busy ? null : _receive,
          onStatement: _busy ? null : _openStatement,
          onFinance: _busy ? null : _openFinance,
          onPurchases: _busy ? null : () => _history(purchases: true),
          onPos: _busy ? null : _openPos,
        ),
      );
    },
  );

  /// Monta a lista de carteiras com o estado atual.
  Widget _walletsPanel() =>
      FutureBuilder<({List<double?> wallets, double? total})>(
        future: _portfolioValue,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final portfolio = loading ? null : snapshot.data;
          return _walletsSummary(portfolio, loading);
        },
      );

  /// Formata o saldo ou exibe o estado de privacidade, carregamento ou falha.
  String _portfolioAmount(double? value, bool loading) {
    if (_hideBalance) return '••••';
    if (loading) return context.l10n.checking;
    return value == null
        ? context.l10n.unavailable
        : _fiatCurrency.format(value);
  }

  /// Monta a lista de carteiras e o total na moeda de comparação.
  Widget _walletsSummary(
    ({List<double?> wallets, double? total})? portfolio,
    bool loading,
  ) => WalletPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletSectionTitle(
          context.l10n.myWallets,
          trailing: PopupMenuButton<AccountMode>(
            enabled: !_busy,
            tooltip: 'Adicionar carteira',
            icon: Icon(Icons.add, color: _colors.primary),
            onSelected: _add,
            itemBuilder: (_) => [
              for (final mode in AccountMode.values)
                PopupMenuItem(value: mode, child: Text(mode.label)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.estimatedTotal(
            _fiatCurrency.code,
            _portfolioAmount(portfolio?.total, loading),
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(context.l10n.referenceQuotes),
        if (_fiatCurrency.code != 'BRL' && _fiatCurrency.code != 'USD')
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => launchUrl(FiatExchangeService.attribution),
              child: const Text('Rates By Exchange Rate API'),
            ),
          ),
        const SizedBox(height: 8),
        for (var index = 0; index < _accounts.length; index++) ...[
          _walletRow(
            index,
            _portfolioAmount(portfolio?.wallets[index], loading),
          ),
          if (index < _accounts.length - 1) const SizedBox(height: 6),
        ],
      ],
    ),
  );

  /// Monta a linha da carteira com o nome, a rede e o valor convertido.
  Widget _walletRow(int index, String fiatValue) {
    final account = _accounts[index];
    final selected = index == _selected;
    final radius = BorderRadius.circular(14);
    final isMulti = account.isMultiCoin;

    return Material(
      color: selected ? _colors.secondaryContainer : _colors.surface,
      borderRadius: radius,
      child: ListTile(
        selected: selected,
        selectedColor: _colors.onSurface,
        shape: RoundedRectangleBorder(borderRadius: radius),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        leading: isMulti
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AssetMark('BTC', size: 22),
                  Transform.translate(
                    offset: const Offset(-6, 0),
                    child: const AssetMark('ETH', size: 22),
                  ),
                ],
              )
            : AssetMark(account.symbol),
        title: Row(
          children: [
            Flexible(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              account.username,
              style: TextStyle(
                color: _colors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${isMulti ? 'Multi-Moeda · ETH & BTC (${account.bitcoinChain?.label ?? 'Testnet4'})' : '${account.symbol} · ${account.bitcoinChain == BitcoinChain.testnet4
                    ? 'Testnet4'
                    : account.bitcoinChain == BitcoinChain.mainnet
                    ? 'Rede principal'
                    : 'Ethereum'}'}\n$fiatValue',
          style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 13),
        ),
        isThreeLine: true,
        trailing: Icon(
          selected ? Icons.check_circle : Icons.chevron_right,
          color: selected ? _colors.primary : _colors.onSurfaceVariant,
          size: 19,
        ),
        onTap: _busy || selected
            ? null
            : () => setState(() {
                _controller.select(index);
                _refreshBalance();
              }),
      ),
    );
  }

  /// Monta o resumo dos cofres com o estado atual.
  Widget _vaultsSummaryPanel() => ValueListenableBuilder<List<CryptoVault>>(
    valueListenable: _vaults,
    builder: (context, vaults, _) {
      final symbolVaults = vaults
          .where((v) => v.symbol.toUpperCase() == _account.symbol.toUpperCase())
          .toList();
      final totalAllocated = _vaults.totalAllocated(_account.symbol);
      final lastBalance = _controller.lastKnownBalance();
      final currentCrypto = lastBalance != null
          ? (_account.bitcoinChain != null
                ? lastBalance.toDouble() / 1e8
                : lastBalance.toDouble() / 1e18)
          : 0.0;
      final freeBalance = (currentCrypto - totalAllocated).clamp(
        0.0,
        double.infinity,
      );

      final currentBudget = _budget.getBudget(_account.symbol);

      return WalletPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WalletSectionTitle(
              'Guardar Dinheiro (Cofres)',
              trailing: TextButton.icon(
                onPressed: _busy ? null : _openFinance,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(context.l10n.financeTitle),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separe dinheiro para seus objetivos ou metas. Fica protegido neste aparelho, sem taxas e sem juros.',
              style: TextStyle(fontSize: 12, color: _colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guardado em Cofres',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${totalAllocated.toStringAsFixed(4)} ${_account.symbol}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colors.secondaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disponível para Usar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${freeBalance.toStringAsFixed(4)} ${_account.symbol}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (symbolVaults.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final vault in symbolVaults.take(2)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            vault.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(vault.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: vault.progress,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (currentBudget.isEnabled) ...[
              const SizedBox(height: 12),
              Divider(color: _colors.outlineVariant),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart, size: 16, color: _colors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Limite do Mês:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${currentBudget.monthlyLimit.toStringAsFixed(4)} ${_account.symbol}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  /// Monta o painel de detalhes com o estado atual.
  Widget _detailsPanel() => WalletPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalletSectionTitle(
          'Endereços para Receber',
          trailing: IconButton(
            tooltip: 'Renomear carteira',
            onPressed: _busy ? null : _rename,
            icon: Icon(Icons.edit_outlined, color: _colors.primary),
          ),
        ),
        const SizedBox(height: 14),
        if (_account.isMultiCoin) ...[
          _addressItem('Endereço Ethereum', _account.ethAddress ?? ''),
          const SizedBox(height: 12),
          _addressItem('Endereço Bitcoin', _account.btcAddress ?? ''),
        ] else ...[
          _addressItem(
            _account.bitcoinChain != null
                ? 'Endereço Bitcoin'
                : 'Endereço Ethereum',
            _account.publicAddress,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _account.canSign
              ? 'Carteira protegida e controlada por você'
              : 'Modo observador (somente leitura)',
          style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _openStatement,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Histórico completo'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _history,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Comprovantes'),
            ),
          ],
        ),
      ],
    ),
  );

  /// Monta a linha do endereço e suas ações de cópia.
  Widget _addressItem(String label, String address) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              address,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Copiar $label',
        color: _colors.primary,
        onPressed: () => _copy(address, label),
        icon: const Icon(Icons.copy_outlined, size: 18),
      ),
    ],
  );

  /// Monta o painel de segurança com o estado atual.
  Widget _securityPanel() => WalletPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WalletSectionTitle('Segurança & Proteção'),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.devices_rounded, color: _colors.primary),
          title: const Text('Conectar outro aparelho'),
          subtitle: const Text('Transfira ou compartilhe sua carteira via QR Code de forma segura.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _exportQr,
        ),
        if (_account.canSign)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key_outlined, color: _colors.primary),
            title: const Text('Palavras de recuperação'),
            subtitle: const Text('Guarde suas palavras de segurança para nunca perder acesso ao seu dinheiro.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _backup,
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined, color: Colors.purple),
          title: const Text('Proteção de Tela & Privacidade'),
          subtitle: const Text('Oculte saldos em locais públicos e ative senha de emergência.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _openPrivacyStealth,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined, color: Colors.blueAccent),
          title: const Text('Checar Endereço Seguro'),
          subtitle: const Text('Verifique qualquer endereço antes de transferir para evitar golpes.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _openAddressInspector,
        ),
      ],
    ),
  );
}

class _ServiceItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

