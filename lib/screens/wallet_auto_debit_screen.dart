import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/coin_formatter.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/auto_debit_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/auto_debit_plan.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/wallet_widgets.dart';
import '../widgets/wallet_layout.dart';

class WalletAutoDebitScreen extends StatefulWidget {
  /// Inicializa [WalletAutoDebitScreen] com os dados recebidos.
  const WalletAutoDebitScreen({
    super.key,
    required this.account,
    required this.autoDebits,
    this.walletController,
  });

  final WalletAccount account;
  final AutoDebitController autoDebits;
  final WalletController? walletController;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletAutoDebitScreen> createState() => _WalletAutoDebitScreenState();
}

class _WalletAutoDebitScreenState extends State<WalletAutoDebitScreen> {
  bool _busy = false;

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Alterna o plano.
  Future<void> _togglePlan(AutoDebitPlan plan) async {
    final willCancel = plan.isActive;
    if (willCancel) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar Débito Automático?'),
          content: Text(
            'Você pode cancelar "${plan.title}" a qualquer momento sem custos.\n\nNenhuma nova cobrança será realizada até que você decida reativá-lo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar Cancelamento'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await widget.autoDebits.toggle(plan.id);
      _notify(
        willCancel
            ? 'Débito "${plan.title}" cancelado com sucesso.'
            : 'Débito "${plan.title}" reativado.',
      );
    } catch (_) {
      _notify('Não foi possível alterar o status do débito.');
    }
  }

  /// Executa `now` no fluxo de débitos automáticos.
  Future<void> _executeNow(AutoDebitPlan plan) async {
    if (widget.walletController == null || !widget.account.canSign) {
      _notify('Esta carteira não pode assinar pagamentos on-chain.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Antecipar Pagamento'),
        content: Text(
          'Deseja enviar o pagamento de "${plan.title}" agora?\n\n'
          'Destino: ${plan.recipientAddress}\n'
          'Valor: ${CoinFormatter.format(plan.amount, plan.symbol)} ${plan.symbol}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pagar Agora'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final hash = await widget.autoDebits.executePlan(
        plan: plan,
        walletController: widget.walletController!,
        account: widget.account,
      );
      _notify('Pagamento enviado on-chain! TX: ${hash?.substring(0, 10)}...');
    } catch (e) {
      _notify('Falha ao enviar pagamento: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Exclui o plano.
  Future<void> _deletePlan(AutoDebitPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Registro?'),
        content: Text(
          'Deseja remover permanentemente o registro de "${plan.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.autoDebits.remove(plan.id);
      _notify('Registro removido.');
    }
  }

  /// Abre `create dialog` no fluxo de débitos automáticos.
  Future<void> _openCreateDialog() async {
    final created = await showModalBottomSheet<AutoDebitPlan>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateAutoDebitSheet(
        defaultSymbol: widget.account.symbol,
        walletAddress: widget.account.publicAddress,
      ),
    );

    if (created != null) {
      await widget.autoDebits.add(created);
      _notify('Débito automático "${created.title}" cadastrado com sucesso!');
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return WalletScaffold(
      appBar: AppBar(
        title: const Text('Débito Automático'),
        actions: [
          IconButton(
            tooltip: 'Novo Débito Automático',
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      floatingActionButton: WalletFloatingActionButton(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_card),
        label: 'Novo Débito Automático',
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<AutoDebitPlan>>(
          valueListenable: widget.autoDebits,
          builder: (context, plans, _) {
            final activeCount = plans.where((p) => p.isActive).length;
            final dueCount = plans.where((p) => p.isDue).length;

            final header = <Widget>[
              // Banner Informativo de Soberania e Cancelamento
              BalanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const NetworkBadge('CONTROLE TOTAL', isTest: false),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.lightGreenAccent,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '$activeCount ativo${activeCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Assinaturas & Aluguéis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Agende pagamentos recorrentes sem intermediários. Cancele ou pause qualquer assinatura a qualquer momento com um toque.',
                      style: TextStyle(
                        color: walletHeroMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (dueCount > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$dueCount pagamento${dueCount == 1 ? '' : 's'} vencido${dueCount == 1 ? '' : 's'} pronto${dueCount == 1 ? '' : 's'} para envio.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const WalletSectionTitle('Seus Pagamentos Agendados'),
              const SizedBox(height: 12),

              if (plans.isEmpty)
                WalletPanel(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.autorenew,
                            size: 48,
                            color: colors.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum débito automático ativo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cadastre cobranças recorrentes para aluguel, condomínio, assinaturas ou serviços cripto.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _openCreateDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Cadastrar Primeiro Débito'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ];

            final planCards = [
              for (final plan in plans)
                _AutoDebitCard(
                  plan: plan,
                  isBusy: _busy,
                  onToggle: () => _togglePlan(plan),
                  onExecuteNow: () => _executeNow(plan),
                  onDelete: () => _deletePlan(plan),
                ),
            ];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = walletLayoutWidth(context, constraints.maxWidth) >= 780;

                    return ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 400 ? 12 : 16,
                        vertical: 16,
                      ),
                      children: [
                        ...header,
                        if (plans.isNotEmpty)
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < planCards.length; i += 2)
                                        planCards[i],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      for (var i = 1; i < planCards.length; i += 2)
                                        planCards[i],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            ...planCards,
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AutoDebitCard extends StatelessWidget {
  /// Inicializa [_AutoDebitCard] com os dados recebidos.
  const _AutoDebitCard({
    required this.plan,
    required this.isBusy,
    required this.onToggle,
    required this.onExecuteNow,
    required this.onDelete,
  });

  final AutoDebitPlan plan;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onExecuteNow;
  final VoidCallback onDelete;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formattedAmount = CoinFormatter.format(plan.amount, plan.symbol);

    final isEth = plan.symbol == 'ETH';
    final doubleAmount = isEth
        ? plan.amount.toDouble() / 1e18
        : plan.amount.toDouble() / 1e8;
    final fiat = CryptoFinanceService.convertCrypto(
      symbol: plan.symbol,
      amount: doubleAmount,
    );

    final nextFormatted =
        '${plan.nextExecution.day.toString().padLeft(2, '0')}/${plan.nextExecution.month.toString().padLeft(2, '0')}/${plan.nextExecution.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isDue
              ? Colors.amber.withValues(alpha: 0.8)
              : (plan.isActive
                    ? colors.outlineVariant
                    : colors.outlineVariant.withValues(alpha: 0.3)),
          width: plan.isDue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha do Topo: Categoria + Título + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: plan.isActive
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  child: Icon(
                    plan.category.icon,
                    size: 20,
                    color: plan.isActive ? colors.primary : colors.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: plan.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan.category.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${plan.frequency.label} · Próxima: $nextFormatted',
                        style: TextStyle(
                          fontSize: 12,
                          color: plan.isDue
                              ? Colors.amber.shade700
                              : colors.onSurfaceVariant,
                          fontWeight: plan.isDue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: plan.isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    plan.isActive ? 'Ativo' : 'Cancelado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: plan.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Linha de Valor e Destino
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor Recorrente',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$formattedAmount ${plan.symbol}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'R\$ ${fiat.brl.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Destinatário',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            plan.recipientAddress.length > 12
                                ? '${plan.recipientAddress.substring(0, 6)}...${plan.recipientAddress.substring(plan.recipientAddress.length - 4)}'
                                : plan.recipientAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Copiar endereço',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: plan.recipientAddress),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Endereço copiado.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Botões de Ação: Cancelamento claro e Pagamento
            Row(
              children: [
                // Botão de Cancelar / Reativar
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: plan.isActive
                          ? Colors.red
                          : Colors.green,
                      side: BorderSide(
                        color: plan.isActive
                            ? Colors.red.withValues(alpha: 0.5)
                            : Colors.green.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: isBusy ? null : onToggle,
                    icon: Icon(
                      plan.isActive ? Icons.cancel_outlined : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(
                      plan.isActive ? 'Cancelar Débito' : 'Reativar Débito',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                if (plan.isActive)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : onExecuteNow,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text(
                        'Pagar Agora',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                IconButton(
                  tooltip: 'Excluir registro',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: isBusy ? null : onDelete,
                ),
              ],
            ),

            // Histórico de Execuções se houver
            if (plan.executions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Histórico de pagamentos (${plan.executions.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  children: [
                    for (final exec in plan.executions.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              exec.success
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: 14,
                              color: exec.success ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${exec.timestamp.day}/${exec.timestamp.month}/${exec.timestamp.year}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const Spacer(),
                            Text(
                              exec.txHash.length > 10
                                  ? '${exec.txHash.substring(0, 6)}...${exec.txHash.substring(exec.txHash.length - 4)}'
                                  : exec.txHash,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateAutoDebitSheet extends StatefulWidget {
  /// Inicializa [_CreateAutoDebitSheet] com os dados recebidos.
  const _CreateAutoDebitSheet({
    required this.defaultSymbol,
    this.walletAddress,
  });

  final String defaultSymbol;
  final String? walletAddress;

  /// Cria o estado local associado ao widget.
  @override
  State<_CreateAutoDebitSheet> createState() => _CreateAutoDebitSheetState();
}

class _CreateAutoDebitSheetState extends State<_CreateAutoDebitSheet> {
  final _titleController = TextEditingController();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  late String _symbol;
  AutoDebitCategory _category = AutoDebitCategory.subscription;
  AutoDebitFrequency _frequency = AutoDebitFrequency.monthly;
  bool _autoExecution = false;
  String? _error;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _symbol = widget.defaultSymbol;
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _titleController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Persiste os dados para uso nas próximas sessões.
  void _save() {
    final title = _titleController.text.trim();
    final recipient = _recipientController.text.trim();
    final amountStr = _amountController.text.trim();

    if (title.isEmpty) {
      setState(() => _error = 'Informe o nome do serviço ou aluguel.');
      return;
    }
    if (recipient.isEmpty) {
      setState(() => _error = 'Informe o endereço de destino.');
      return;
    }

    // Validação de endereço
    if (_symbol == 'ETH') {
      try {
        parseAddress(recipient);
      } catch (_) {
        setState(() => _error = 'Endereço Ethereum inválido.');
        return;
      }
    } else {
      try {
        parseBitcoinAddress(BitcoinChain.testnet4, recipient);
      } catch (_) {
        setState(() => _error = 'Endereço Bitcoin inválido.');
        return;
      }
    }

    BigInt amount;
    try {
      amount = CoinFormatter.parse(amountStr, _symbol);
      if (amount <= BigInt.zero) throw const FormatException();
    } catch (_) {
      setState(() => _error = 'Valor monetário inválido.');
      return;
    }

    final plan = AutoDebitPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: _category,
      recipientAddress: recipient,
      amount: amount,
      symbol: _symbol,
      frequency: _frequency,
      created: DateTime.now(),
      nextExecution: DateTime.now().add(Duration(days: _frequency.days)),
      isActive: true,
      autoExecution: _autoExecution,
      walletAddress: widget.walletAddress,
    );

    Navigator.pop(context, plan);
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_card, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Novo Débito Automático',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cadastre um aluguel, mensalidade ou assinatura. Cancele quando quiser.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Chips de Categoria
            const Text(
              'Categoria:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AutoDebitCategory.values.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  avatar: Icon(cat.icon, size: 16),
                  label: Text(cat.label),
                  selected: selected,
                  onSelected: (val) {
                    if (val) setState(() => _category = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Título
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título da cobrança (Ex: Aluguel, Servidor)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Moeda
            Row(
              children: [
                const Text(
                  'Moeda:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ETH', label: Text('Ethereum')),
                    ButtonSegment(value: 'BTC', label: Text('Bitcoin')),
                  ],
                  selected: {_symbol},
                  onSelectionChanged: (val) =>
                      setState(() => _symbol = val.first),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Endereço Destino
            TextField(
              controller: _recipientController,
              decoration: InputDecoration(
                labelText: 'Endereço do Destinatário',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  tooltip: 'Colar endereço',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _recipientController.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Valor
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Valor em $_symbol',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Frequência
            const Text(
              'Frequência de Cobrança:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AutoDebitFrequency.values.map((freq) {
                final selected = _frequency == freq;
                return ChoiceChip(
                  label: Text(freq.label),
                  selected: selected,
                  onSelected: (val) {
                    if (val) setState(() => _frequency = freq);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Auto-execução switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enviar sem confirmação'),
              subtitle: const Text(
                'Quando ativado, o app pode assinar e enviar na data prevista durante a sincronização. Você pode desativar o plano a qualquer momento.',
                style: TextStyle(fontSize: 12),
              ),
              value: _autoExecution,
              onChanged: (val) => setState(() => _autoExecution = val),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar Débito Automático'),
            ),
          ],
        ),
      ),
    );
  }
}
