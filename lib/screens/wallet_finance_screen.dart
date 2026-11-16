import 'package:flutter/material.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/coin_formatter.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/auto_debit_controller.dart';
import '../controllers/budget_controller.dart';
import '../controllers/contacts_controller.dart';
import '../controllers/goals_controller.dart';
import '../controllers/group_purchase_controller.dart';
import '../controllers/vaults_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/auto_debit_plan.dart';
import '../models/crypto_vault.dart';
import '../models/financial_goal.dart';
import '../models/group_purchase.dart';
import '../models/spending_budget.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/wallet_widgets.dart';
import 'group_purchases_screen.dart';
import 'wallet_auto_debit_screen.dart';
import 'crypto_market_screen.dart';

class WalletFinanceScreen extends StatefulWidget {
  /// Inicializa [WalletFinanceScreen] com os dados recebidos.
  const WalletFinanceScreen({
    super.key,
    required this.account,
    required this.balance,
    required this.goals,
    this.vaults,
    this.budget,
    this.autoDebits,
    this.walletController,
    this.contacts,
    this.groupPurchases,
    this.initialTab = FinanceTab.converter,
  });

  final WalletAccount account;
  final BigInt balance;
  final GoalsController goals;
  final VaultsController? vaults;
  final BudgetController? budget;
  final AutoDebitController? autoDebits;
  final WalletController? walletController;
  final ContactsController? contacts;
  final GroupPurchaseController? groupPurchases;
  final FinanceTab initialTab;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletFinanceScreen> createState() => _WalletFinanceScreenState();
}

enum FinanceTab {
  converter('Conversor', Icons.currency_exchange),
  vaults('Cofres & Caixinhas', Icons.savings_outlined),
  groupPurchases('Compra Conjunta', Icons.group_work_outlined),
  autoDebit('Débito Automático', Icons.autorenew),
  goals('Metas', Icons.flag_outlined),
  budget('Orçamento', Icons.pie_chart_outline),
  dca('Simulador DCA', Icons.trending_up),
  fees('Taxas de Rede', Icons.speed);

  /// Inicializa a configuração de ferramentas financeiras.
  const FinanceTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _WalletFinanceScreenState extends State<WalletFinanceScreen> {
  late FinanceTab _tab;
  static const _finance = CryptoFinanceService();

  late final VaultsController _vaults;
  late final BudgetController _budget;
  late final AutoDebitController _autoDebits;
  late final GroupPurchaseController _groupPurchases;
  bool _internalVaults = false;
  bool _internalBudget = false;
  bool _internalAutoDebits = false;
  bool _internalGroupPurchases = false;

  // Estado do Conversor
  final _cryptoInput = TextEditingController();
  final _fiatInput = TextEditingController();
  bool _isEditingCrypto = true;

  // Estado do Simulador DCA
  double _dcaAmountBrl = 250.0;
  int _dcaMonths = 12;
  final int _dcaFrequencyDays = 30; // 30 = Mensal, 7 = Semanal
  late bool _dcaIsBitcoin;

  /// Retorna as metas em uso.
  GoalsController get _goals => widget.goals;

  /// Indica se o ativo em uso é Bitcoin.
  bool get _isBitcoin => widget.account.bitcoinChain != null;

  /// Retorna por ativo em uso.
  String get _symbol => widget.account.symbol;

  /// Retorna `currentBalanceCrypto` para consulta em ferramentas financeiras.
  double get _currentBalanceCrypto {
    if (widget.balance == BigInt.zero) return 0.0;
    return _isBitcoin
        ? widget.balance.toDouble() / 1e8
        : widget.balance.toDouble() / 1e18;
  }

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _dcaIsBitcoin = _isBitcoin;

    if (widget.vaults != null) {
      _vaults = widget.vaults!;
    } else {
      _vaults = VaultsController();
      _internalVaults = true;
      _vaults.load();
    }

    if (widget.budget != null) {
      _budget = widget.budget!;
    } else {
      _budget = BudgetController();
      _internalBudget = true;
      _budget.load();
    }

    if (widget.autoDebits != null) {
      _autoDebits = widget.autoDebits!;
    } else {
      _autoDebits = AutoDebitController();
      _internalAutoDebits = true;
      _autoDebits.load();
    }

    if (widget.groupPurchases != null) {
      _groupPurchases = widget.groupPurchases!;
    } else {
      _groupPurchases = GroupPurchaseController();
      _internalGroupPurchases = true;
      _groupPurchases.load();
    }

    if (!_goals.loaded) _goals.load();
    _initConverterWithBalance();
  }

  /// Inicializa `converter with balance` no fluxo de ferramentas financeiras.
  void _initConverterWithBalance() {
    if (widget.balance > BigInt.zero) {
      if (_isBitcoin) {
        final btc = formatBtc(widget.balance, separator: '.');
        _cryptoInput.text = btc;
        _fiatInput.text = _finance.satsToBrl(widget.balance).toStringAsFixed(2);
      } else {
        final eth = formatEth(widget.balance).replaceAll(',', '.');
        _cryptoInput.text = eth;
        _fiatInput.text = _finance.weiToBrl(widget.balance).toStringAsFixed(2);
      }
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _cryptoInput.dispose();
    _fiatInput.dispose();
    if (_internalVaults) _vaults.dispose();
    if (_internalBudget) _budget.dispose();
    if (_internalAutoDebits) _autoDebits.dispose();
    if (_internalGroupPurchases) _groupPurchases.dispose();
    super.dispose();
  }

  /// Recalcula a estimativa fiduciária quando o valor cripto muda.
  void _onCryptoChanged(String val) {
    if (!_isEditingCrypto) return;
    final text = val.trim().replaceAll(',', '.');
    final amount = double.tryParse(text) ?? 0.0;
    if (_isBitcoin) {
      final brl = amount * CryptoFinanceService.btcPriceBrl;
      _fiatInput.text = brl > 0 ? brl.toStringAsFixed(2) : '';
    } else {
      final brl = amount * CryptoFinanceService.ethPriceBrl;
      _fiatInput.text = brl > 0 ? brl.toStringAsFixed(2) : '';
    }
  }

  /// Recalcula o valor em criptomoeda quando a entrada fiduciária muda.
  void _onFiatChanged(String val) {
    if (_isEditingCrypto) return;
    final text = val.trim().replaceAll(',', '.');
    final fiat = double.tryParse(text) ?? 0.0;
    if (_isBitcoin) {
      final btc = fiat / CryptoFinanceService.btcPriceBrl;
      _cryptoInput.text = btc > 0 ? btc.toStringAsFixed(8) : '';
    } else {
      final eth = fiat / CryptoFinanceService.ethPriceBrl;
      _cryptoInput.text = eth > 0 ? eth.toStringAsFixed(6) : '';
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças Cripto · Gestão Patrimonial'),
        actions: [
          IconButton(
            tooltip: 'Mercado & Alertas',
            icon: const Icon(Icons.trending_up),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const CryptoMarketScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _tab == FinanceTab.goals
          ? FloatingActionButton.extended(
              onPressed: _addNewGoalDialog,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Nova meta'),
            )
          : _tab == FinanceTab.vaults
          ? FloatingActionButton.extended(
              onPressed: _addNewVaultDialog,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Novo cofre'),
            )
          : _tab == FinanceTab.autoDebit
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletAutoDebitScreen(
                    account: widget.account,
                    autoDebits: _autoDebits,
                    walletController: widget.walletController,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_card),
              label: const Text('Gerenciar débitos'),
            )
          : _tab == FinanceTab.groupPurchases
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupPurchasesScreen(
                    controller: _groupPurchases,
                    contacts: widget.contacts ?? ContactsController(),
                    account: widget.account,
                  ),
                ),
              ),
              icon: const Icon(Icons.group_work_outlined),
              label: const Text('Nova compra conjunta'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Coluna de Navegação Lateral em telas largas
                        SizedBox(
                          width: 260,
                          child: Card(
                            margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'MÓDULOS BANCÁRIOS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  for (final tab in FinanceTab.values)
                                    ListTile(
                                      leading: Icon(
                                        tab.icon,
                                        color: _tab == tab
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : null,
                                      ),
                                      title: Text(
                                        tab.label,
                                        style: TextStyle(
                                          fontWeight: _tab == tab
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      selected: _tab == tab,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      onTap: () => setState(() => _tab = tab),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Conteúdo Principal Expandido
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 16, 24, 32),
                            child: _buildCurrentTabView(isWide: true),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<FinanceTab>(
                              showSelectedIcon: false,
                              segments: [
                                for (final tab in FinanceTab.values)
                                  ButtonSegment(
                                    value: tab,
                                    icon: Icon(tab.icon, size: 16),
                                    label: Text(tab.label),
                                  ),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (set) =>
                                  setState(() => _tab = set.single),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            child: _buildCurrentTabView(isWide: false),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  /// Monta `current tab view` no fluxo de ferramentas financeiras.
  Widget _buildCurrentTabView({required bool isWide}) {
    return switch (_tab) {
      FinanceTab.converter => _buildConverterView(isWide: isWide),
      FinanceTab.vaults => _buildVaultsView(isWide: isWide),
      FinanceTab.groupPurchases => _buildGroupPurchasesView(isWide: isWide),
      FinanceTab.autoDebit => _buildAutoDebitView(isWide: isWide),
      FinanceTab.goals => _buildGoalsView(isWide: isWide),
      FinanceTab.budget => _buildBudgetView(isWide: isWide),
      FinanceTab.dca => _buildDcaView(isWide: isWide),
      FinanceTab.fees => _buildFeesView(isWide: isWide),
    };
  }

  /// Monta a aba de compras conjuntas.
  Widget _buildGroupPurchasesView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<List<GroupPurchase>>(
      valueListenable: _groupPurchases,
      builder: (context, purchases, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: colors.primaryContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_work_outlined,
                        size: 36,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compras Conjuntas & Rachas Coletivos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Divida custos de viagens, almoços, presentes ou despesas com seus amigos soberanamente.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suas Compras Conjuntas (${purchases.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Abrir Painel'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupPurchasesScreen(
                          controller: _groupPurchases,
                          contacts: widget.contacts ?? ContactsController(),
                          account: widget.account,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (purchases.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.handshake_outlined,
                            size: 48,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma compra conjunta criada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crie um racha agora e convide seus amigos pelo identificador único (PW-ID) ou QR Code!',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Primeira Compra Conjunta'),
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupPurchasesScreen(
                                  controller: _groupPurchases,
                                  contacts:
                                      widget.contacts ?? ContactsController(),
                                  account: widget.account,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final p in purchases) ...[
                  Card(
                    child: ListTile(
                      leading: AssetMark(p.asset, size: 32),
                      title: Text(
                        p.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${p.paidMembersCount}/${p.totalMembers} pagos · Total: ${p.totalAmount} ${p.asset}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.isSettled
                              ? Colors.green.withValues(alpha: 0.15)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.isSettled
                              ? 'Concluído'
                              : '${(p.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: p.isSettled ? Colors.green : colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupPurchasesScreen(
                            controller: _groupPurchases,
                            contacts: widget.contacts ?? ContactsController(),
                            account: widget.account,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // ABA 1: CONVERSOR & VALUATION
  // ==========================================
  /// Monta o conversor.
  Widget _buildConverterView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    final symbol = widget.account.symbol;
    final double balanceFiatBrl = _isBitcoin
        ? _finance.satsToBrl(widget.balance)
        : _finance.weiToBrl(widget.balance);
    final double balanceFiatUsd = _isBitcoin
        ? _finance.satsToUsd(widget.balance)
        : _finance.weiToUsd(widget.balance);

    /// Formata o saldo.
    String formatBalance() =>
        _isBitcoin ? formatBtc(widget.balance) : formatEth(widget.balance);

    final valuationCard = BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valuation Patrimonial · ${widget.account.name}',
            style: const TextStyle(
              color: walletHeroMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBalance()} $symbol',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Em Reais (BRL)',
                        style: TextStyle(color: walletHeroMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'R\$ ${balanceFiatBrl.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Em Dólares (USD)',
                        style: TextStyle(color: walletHeroMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$ ${balanceFiatUsd.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final calculatorCard = WalletPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WalletSectionTitle('Calculadora de Câmbio Instantânea'),
          const SizedBox(height: 8),
          Text(
            'Cotação de referência: 1 BTC ≈ R\$ ${(CryptoFinanceService.btcPriceBrl / 1000).toStringAsFixed(0)}k | 1 ETH ≈ R\$ ${(CryptoFinanceService.ethPriceBrl / 1000).toStringAsFixed(1)}k',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cryptoInput,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Valor em $symbol',
              suffixText: symbol,
              prefixIcon: const Icon(Icons.currency_bitcoin),
            ),
            onTap: () => setState(() => _isEditingCrypto = true),
            onChanged: _onCryptoChanged,
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton(
              icon: const Icon(Icons.swap_vert_rounded),
              onPressed: () {
                setState(() => _isEditingCrypto = !_isEditingCrypto);
              },
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _fiatInput,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor em Reais (BRL)',
              prefixText: 'R\$ ',
              prefixIcon: Icon(Icons.attach_money),
            ),
            onTap: () => setState(() => _isEditingCrypto = false),
            onChanged: _onFiatChanged,
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: valuationCard),
          const SizedBox(width: 16),
          Expanded(child: calculatorCard),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [valuationCard, const SizedBox(height: 16), calculatorCard],
    );
  }

  // ==========================================
  // ABA 2: COFRES & CAIXINHAS (BANK-FEEL)
  // ==========================================
  /// Monta a aba de cofres.
  Widget _buildVaultsView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<CryptoVault>>(
      valueListenable: _vaults,
      builder: (context, vaults, _) {
        final symbolVaults = vaults
            .where((v) => v.symbol.toUpperCase() == _symbol.toUpperCase())
            .toList();
        final totalAllocated = _vaults.totalAllocated(_symbol);
        final freeBalance = (_currentBalanceCrypto - totalAllocated).clamp(
          0.0,
          double.infinity,
        );

        final overviewCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DISTRIBUIÇÃO PATRIMONIAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Novo cofre'),
                      onPressed: _addNewVaultDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '💡 Cofres Virtuais reservam frações do seu saldo localmente para fins específicos sem gerar transações nem custos on-chain.',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo Total',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currentBalanceCrypto.toStringAsFixed(4)} $_symbol',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
                          color: colors.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Em Cofres Guardados',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${totalAllocated.toStringAsFixed(4)} $_symbol',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
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
                          color: colors.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Livre para Gastos',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${freeBalance.toStringAsFixed(4)} $_symbol',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aviso: As caixinhas e cofres são divisões lógicas para planejamento e separação de saldo no seu dispositivo. NÃO rendem juros, dividendos ou retorno financeiro.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (symbolVaults.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              overviewCard,
              const SizedBox(height: 24),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        size: 48,
                        color: colors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum cofre cripto criado ainda.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Crie gavetas virtuais para separar sua reserva de emergência, fundos para HODL ou despesas futuras com segurança soberana.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Criar Primeira Gaveta'),
                        onPressed: _addNewVaultDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final vaultWidgets = [
          for (final vault in symbolVaults)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.savings, color: colors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vault.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (vault.isLocked)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_clock,
                                      size: 13,
                                      color: colors.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Trava mental: restam ${vault.remainingLockDays} dias',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'deposit') {
                              _transferVaultDialog(vault, isDeposit: true);
                            } else if (action == 'withdraw') {
                              _transferVaultDialog(vault, isDeposit: false);
                            } else if (action == 'delete') {
                              _vaults.remove(vault.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'deposit',
                              child: Text('Depositar saldo no cofre'),
                            ),
                            const PopupMenuItem(
                              value: 'withdraw',
                              child: Text('Resgatar para saldo livre'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir cofre'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${vault.allocatedAmount.toStringAsFixed(4)} / ${vault.targetAmount.toStringAsFixed(4)} ${vault.symbol}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(vault.progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: vault.progress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_downward, size: 16),
                          label: const Text('Resgatar'),
                          onPressed: () =>
                              _transferVaultDialog(vault, isDeposit: false),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          label: const Text('Guardar'),
                          onPressed: () =>
                              _transferVaultDialog(vault, isDeposit: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ];

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              overviewCard,
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 210,
                ),
                itemCount: vaultWidgets.length,
                itemBuilder: (_, i) => vaultWidgets[i],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [overviewCard, const SizedBox(height: 16), ...vaultWidgets],
        );
      },
    );
  }

  // ==========================================
  // ABA 3: METAS FINANCEIRAS CRIPTO
  // ==========================================
  /// Monta a aba de metas.
  Widget _buildGoalsView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<FinancialGoal>>(
      valueListenable: _goals,
      builder: (context, goals, _) {
        final symbolGoals = _goals.goalsForSymbol(_symbol);
        if (symbolGoals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 48,
                    color: colors.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma meta ativa para este ativo.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Defina objetivos de poupança (ex: 0.1 BTC para aposentadoria ou 1 ETH para gas) e acompanhe seu progresso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Meta'),
                    onPressed: _addNewGoalDialog,
                  ),
                ],
              ),
            ),
          );
        }

        final cards = [
          for (final goal in symbolGoals)
            _buildGoalCard(goal, _currentBalanceCrypto, colors),
        ];

        if (isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisExtent: 180,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => cards[i],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards,
        );
      },
    );
  }

  /// Monta `goal card` no fluxo de ferramentas financeiras.
  Widget _buildGoalCard(
    FinancialGoal goal,
    double currentBalance,
    ColorScheme colors,
  ) {
    final progress = goal.progress(widget.balance);
    final isDone = goal.isCompleted(widget.balance);
    final targetStr = goal.symbol == 'BTC'
        ? formatBtc(goal.targetAmount)
        : formatEth(goal.targetAmount);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _goals.remove(goal.id),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alvo: $targetStr ${goal.symbol}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Text(
                  isDone
                      ? 'Concluída 🎉'
                      : '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDone ? Colors.green : colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: isDone ? Colors.green : colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA 4: ORÇAMENTO & LIMITES (BANK-FEEL)
  // ==========================================
  /// Monta a aba de orçamento.
  Widget _buildBudgetView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Map<String, SpendingBudget>>(
      valueListenable: _budget,
      builder: (context, budgets, child) {
        final currentBudget = _budget.getBudget(_symbol);
        final limit = currentBudget.monthlyLimit;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pie_chart, color: colors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONTROLE DE GASTOS MENSAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                'Limite de Gastos para $_symbol',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '💡 Defina um teto mensal para manter disciplina financeira. O app monitora saídas para evitar estouro.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (limit <= 0)
                      Column(
                        children: [
                          const Text(
                            'Você ainda não definiu um teto mensal de saídas para esta moeda.',
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            icon: const Icon(Icons.tune),
                            label: const Text('Estipular Teto Mensal'),
                            onPressed: () => _editBudgetDialog(currentBudget),
                          ),
                        ],
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Teto Mensal Definido',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          Text(
                            '${limit.toStringAsFixed(4)} $_symbol / mês',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 0.28, // Estimativa com base no histórico local
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consumo estimado no mês: 28%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Alterar teto'),
                            onPressed: () => _editBudgetDialog(currentBudget),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // ABA 5: SIMULADOR DCA
  // ==========================================
  /// Monta a simulação de aportes periódicos.
  Widget _buildDcaView({required bool isWide}) {
    final symbol = _dcaIsBitcoin ? 'BTC' : 'ETH';
    final result = _finance.simulateDca(
      symbol: symbol,
      periodContributionFiat: _dcaAmountBrl,
      totalPeriods: (_dcaMonths * 30 / _dcaFrequencyDays).round(),
      annualExpectedReturnRate: 0.15,
    );

    final controls = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PARAMETROS DO APORTE RECORRENTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '💡 A estratégia DCA (Dollar-Cost Averaging) reduz o impacto da volatilidade através de aportes regulares com valor fixo.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Bitcoin (BTC)')),
                      ButtonSegment(
                        value: false,
                        label: Text('Ethereum (ETH)'),
                      ),
                    ],
                    selected: {_dcaIsBitcoin},
                    onSelectionChanged: (s) =>
                        setState(() => _dcaIsBitcoin = s.single),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Valor de cada aporte: R\$ ${_dcaAmountBrl.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _dcaAmountBrl,
              min: 50,
              max: 2000,
              divisions: 39,
              onChanged: (v) => setState(() => _dcaAmountBrl = v),
            ),
            Text(
              'Horizonte de tempo: $_dcaMonths meses',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _dcaMonths.toDouble(),
              min: 3,
              max: 60,
              divisions: 19,
              onChanged: (v) => setState(() => _dcaMonths = v.round()),
            ),
          ],
        ),
      ),
    );

    final resultsCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROJEÇÃO DE RESULTADO PATRIMONIAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${result.totalCryptoAccumulated.toStringAsFixed(6)} $symbol',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Total desembolsado: R\$ ${result.totalFiatInvested.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Patrimônio estimado futuro: R\$ ${result.estimatedFiatPortfolioValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: controls),
          const SizedBox(width: 16),
          Expanded(child: resultsCard),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [controls, const SizedBox(height: 16), resultsCard],
    );
  }

  // ==========================================
  // ABA 6: TAXAS DE REDE
  // ==========================================
  /// Monta a aba de taxas.
  Widget _buildFeesView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: colors.primary),
                const SizedBox(width: 10),
                const Text(
                  'Monitor de Taxas de Rede',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Bitcoin as taxas são medidas em satoshis por byte virtual (sat/vB), e no Ethereum em Gwei por unidade de Gas. Em momentos de baixo congestionamento (como fins de semana e madrugadas), as transferências podem custar até 70% menos.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogos de ação
  /// Adiciona `new goal dialog` no fluxo de ferramentas financeiras.
  Future<void> _addNewGoalDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nova Meta em $_symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Objetivo da meta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quantidade Alvo em $_symbol',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final text = amountCtrl.text.trim();
              final target = double.tryParse(text) ?? 0.0;
              if (title.isNotEmpty && target > 0) {
                final targetBigInt = _isBitcoin
                    ? parseBtc(text)
                    : parseEth(text);
                _goals.add(
                  FinancialGoal(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    targetAmount: targetBigInt,
                    symbol: _symbol,
                    createdAt: DateTime.now(),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  /// Adiciona `new vault dialog` no fluxo de ferramentas financeiras.
  Future<void> _addNewVaultDialog() async {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final depositCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novo Cofre Cripto ($_symbol)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Nota: Cofres virtuais servem exclusivamente para organização interna e metas. NÃO rendem juros nem dinheiro.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Cofre (ex: Reserva, HODL)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Meta Alvo ($_symbol)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: depositCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Aporte Inicial Opcional ($_symbol)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final target = double.tryParse(targetCtrl.text.trim()) ?? 0.0;
              final initial = double.tryParse(depositCtrl.text.trim()) ?? 0.0;
              if (title.isNotEmpty && target > 0) {
                _vaults.add(
                  CryptoVault(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    targetAmount: target,
                    allocatedAmount: initial,
                    symbol: _symbol,
                    createdAt: DateTime.now(),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Criar Cofre'),
          ),
        ],
      ),
    );
  }

  /// Abre o diálogo de movimentação da reserva virtual do cofre.
  Future<void> _transferVaultDialog(
    CryptoVault vault, {
    required bool isDeposit,
  }) async {
    final amountCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isDeposit
              ? 'Guardar em "${vault.title}"'
              : 'Resgatar de "${vault.title}"',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDeposit
                  ? 'Transfira saldo livre para proteger e guardar nesta caixinha.'
                  : 'Mova saldo de volta para o saldo livre disponível para transações.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Valor em ${vault.symbol}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt > 0) {
                if (isDeposit) {
                  _vaults.deposit(vault.id, amt);
                } else {
                  _vaults.withdraw(vault.id, amt);
                }
              }
              Navigator.pop(context);
            },
            child: Text(isDeposit ? 'Guardar' : 'Resgatar'),
          ),
        ],
      ),
    );
  }

  /// Abre a edição de `budget dialog` no fluxo de ferramentas financeiras.
  Future<void> _editBudgetDialog(SpendingBudget current) async {
    final limitCtrl = TextEditingController(
      text: current.monthlyLimit > 0 ? current.monthlyLimit.toString() : '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Definir Teto Mensal ($_symbol)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Estipule um valor máximo que pretende transferir neste mês para controle orçamentário.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Limite Mensal em $_symbol',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final limit = double.tryParse(limitCtrl.text.trim()) ?? 0.0;
              _budget.setMonthlyLimit(_symbol, limit);
              Navigator.pop(context);
            },
            child: const Text('Salvar Limite'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA: DÉBITO AUTOMÁTICO (ASSINATURAS & ALUGUÉIS)
  // ==========================================
  /// Monta a aba de débitos automáticos.
  Widget _buildAutoDebitView({required bool isWide}) {
    final colors = Theme.of(context).colorScheme;

    final bannerCard = BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NetworkBadge('SOBERANIA BANCÁRIA CRIPTO', isTest: false),
          const SizedBox(height: 12),
          const Text(
            'Débito Automático & Assinaturas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Assinaturas, aluguéis e mensalidades gerenciados sem custodiantes. Você tem o direito inalienável de cancelar qualquer cobrança a qualquer momento com 1 clique.',
            style: TextStyle(color: walletHeroMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.primary,
            ),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => WalletAutoDebitScreen(
                  account: widget.account,
                  autoDebits: _autoDebits,
                  walletController: widget.walletController,
                ),
              ),
            ),
            icon: const Icon(Icons.settings_suggest_outlined),
            label: const Text('Abrir Painel Completo de Débito Automático'),
          ),
        ],
      ),
    );

    final content = ValueListenableBuilder<List<AutoDebitPlan>>(
      valueListenable: _autoDebits,
      builder: (context, plans, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WalletPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const WalletSectionTitle('Compromissos Recorrentes'),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Ver tudo'),
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WalletAutoDebitScreen(
                              account: widget.account,
                              autoDebits: _autoDebits,
                              walletController: widget.walletController,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (plans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Nenhum débito automático cadastrado ainda.\nAdicione aluguéis ou assinaturas no painel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  else ...[
                    for (final plan in plans.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: plan.isActive
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          child: Icon(
                            plan.category.icon,
                            color: plan.isActive
                                ? colors.primary
                                : colors.outline,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          plan.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: plan.isActive
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${plan.frequency.label} · ${CoinFormatter.format(plan.amount, plan.symbol)} ${plan.symbol}',
                          style: TextStyle(
                            fontSize: 12,
                            color: plan.isDue ? Colors.amber.shade700 : null,
                            fontWeight: plan.isDue
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              plan.isActive ? 'Ativo' : 'Cancelado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: plan.isActive
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: plan.isActive
                                  ? 'Cancelar a qualquer momento'
                                  : 'Reativar',
                              icon: Icon(
                                plan.isActive
                                    ? Icons.cancel_outlined
                                    : Icons.play_arrow,
                                size: 18,
                                color: plan.isActive
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              onPressed: () => _autoDebits.toggle(plan.id),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: bannerCard),
          const SizedBox(width: 20),
          Expanded(flex: 5, child: content),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [bannerCard, const SizedBox(height: 16), content],
    );
  }
}
