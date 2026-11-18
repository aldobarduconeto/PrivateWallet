import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/contacts_controller.dart';
import '../controllers/statement_controller.dart';
import '../models/chain_movement.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import '../models/wallet_contact.dart';
import '../theme/wallet_theme.dart';
import '../widgets/crypto_receipt_dialog.dart';
import '../widgets/wallet_form.dart';
import '../widgets/wallet_widgets.dart';
import '../widgets/wallet_layout.dart';

class WalletStatementScreen extends StatefulWidget {
  /// Inicializa [WalletStatementScreen] com os dados recebidos.
  const WalletStatementScreen({
    super.key,
    required this.account,
    required this.network,
    required this.statement,
    required this.contacts,
    required this.addressExplorer,
  });

  final WalletAccount account;
  final Network network;
  final StatementController statement;
  final ContactsController contacts;
  final Uri addressExplorer;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletStatementScreen> createState() => _WalletStatementScreenState();
}

class _WalletStatementScreenState extends State<WalletStatementScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';

  /// Retorna o extrato em uso.
  StatementController get _statement => widget.statement;

  /// Retorna os contatos em uso.
  ContactsController get _contacts => widget.contacts;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _scrollController.addListener(_onScroll);
    if (!_statement.loadedOnce && !_statement.loading) {
      _statement.refresh();
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Verifica se a rolagem chegou perto do fim para carregar outra página.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_statement.hasMore && !_statement.loadingMore) {
        _statement.loadMore();
      }
    }
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Abre o endereço externo com o aplicativo disponível no sistema.
  Future<void> _openUrl(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Falha tratada abaixo
    }
    _notify('Não foi possível abrir o navegador.');
  }

  /// Identifica o contato.
  String? _resolveContact(String? address) {
    if (address == null) return null;
    return _contacts.find(address, widget.account.bitcoinChain)?.name;
  }

  /// Solicita a seleção de o dia.
  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _statement.period?.start ?? now,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: 'Filtrar por dia',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    await _statement.setPeriod(StatementPeriod.day(picked));
  }

  /// Solicita a seleção de o intervalo de datas personalizado.
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: now,
      initialDateRange: _statement.period != null
          ? DateTimeRange(
              start: _statement.period!.start,
              end: _statement.period!.end.subtract(const Duration(days: 1)),
            )
          : null,
      helpText: 'Filtrar período do extrato',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (range == null || !mounted) return;
    await _statement.setPeriod(StatementPeriod.range(range.start, range.end));
  }

  /// Copia `statement text` no fluxo de extrato.
  void _copyStatementText(List<ChainMovement> items) {
    if (items.isEmpty) {
      _notify('Nenhuma movimentação para copiar.');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('Extrato Private Wallet · ${widget.account.name}');
    buffer.writeln(
      'Rede: ${widget.account.bitcoinChain?.label ?? widget.network.label}',
    );
    buffer.writeln('Endereço: ${widget.account.publicAddress}');
    buffer.writeln('Filtro período: ${_statement.period?.label ?? "Todos"}');
    buffer.writeln('Filtro tipo: ${_statement.type?.label ?? "Todos"}');
    buffer.writeln('----------------------------------------');
    for (final item in items) {
      final date = item.time != null ? dayLabel(item.time!) : 'Pendente';
      final time = item.time != null ? timeLabel(item.time!) : '';
      final sign = item.type == MovementType.incoming ? '+' : '−';
      final contact = _resolveContact(item.counterparty);
      final party =
          contact ??
          (item.counterparty != null ? shortAddress(item.counterparty!) : '');
      buffer.writeln(
        '$date $time | ${item.type.label} | $sign${item.format(item.amount)} ${item.symbol} | $party | Hash: ${item.hash}',
      );
    }
    buffer.writeln('----------------------------------------');
    final s = _statement.summary;
    buffer.writeln(
      'Entradas: ${widget.account.bitcoinChain == null ? formatEth(s.incoming) : formatBtc(s.incoming)} ${widget.account.symbol}',
    );
    buffer.writeln(
      'Saídas: ${widget.account.bitcoinChain == null ? formatEth(s.outgoing) : formatBtc(s.outgoing)} ${widget.account.symbol}',
    );
    buffer.writeln(
      'Taxas: ${widget.account.bitcoinChain == null ? formatEth(s.fees) : formatBtc(s.fees)} ${widget.account.symbol}',
    );
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _notify('Extrato copiado para a área de transferência.');
  }

  /// Salva `contact dialog` no fluxo de extrato.
  Future<void> _saveContactDialog(String address) async {
    final contact = await showDialog<WalletContact>(
      context: context,
      builder: (_) => WalletForm(
        title: 'Salvar contato',
        description: address,
        action: 'Salvar',
        fields: const [(label: 'Nome', secret: false, amount: false)],
        submit: (values) => WalletContact.parse(
          values.single,
          address,
          bitcoin: widget.account.bitcoinChain,
        ),
      ),
    );
    if (!mounted || contact == null) return;
    try {
      await _contacts.add(contact);
      setState(() {});
      _notify('Contato salvo com sucesso.');
    } on FormatException catch (f) {
      _notify(f.message);
    } catch (_) {
      _notify('Não foi possível salvar o contato.');
    }
  }

  /// Exibe `movement details` no fluxo de extrato.
  void _showMovementDetails(ChainMovement item) {
    final contact = _resolveContact(item.counterparty);
    final isKnownContact = contact != null;
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.type.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.type == MovementType.incoming ? '+' : '−'}${item.format(item.amount)} ${item.symbol}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                            color: item.type == MovementType.incoming
                                ? (colors.brightness == Brightness.dark
                                      ? const Color(0xff80e2a7)
                                      : const Color(0xff167e43))
                                : colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(item),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if (item.time != null)
                _detailRow(
                  'Data e hora',
                  '${dayLabel(item.time!)} às ${timeLabel(item.time!)}',
                ),
              if (item.counterparty case final party?) ...[
                _detailRow(
                  item.type == MovementType.incoming
                      ? 'Recebido de'
                      : 'Enviado para',
                  contact != null ? '$contact\n$party' : party,
                ),
                if (!isKnownContact && item.counterparty != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveContactDialog(item.counterparty!);
                      },
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Salvar este endereço na agenda'),
                    ),
                  ),
              ],
              if (item.paymentType case final pType?)
                _detailRow('Tipo de pagamento', pType),
              if (item.fee != null && item.fee! > BigInt.zero)
                _detailRow(
                  'Taxa de rede',
                  '${item.format(item.fee!)} ${item.symbol}',
                ),
              _detailRow('Identificador (Hash)', item.hash),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showCryptoReceipt(
                        context: context,
                        activity: WalletActivity(
                          hash: item.hash,
                          recipient:
                              item.counterparty ?? widget.account.publicAddress,
                          amount: item.amount,
                          estimatedFee: item.fee ?? BigInt.zero,
                          created: item.time ?? DateTime.now(),
                          contactName: contact,
                          paymentType:
                              item.paymentType ?? 'Transferência Cripto',
                        ),
                        ethereumNetwork: widget.account.bitcoinChain == null
                            ? widget.network
                            : null,
                        bitcoinChain: widget.account.bitcoinChain,
                        fromAddress: item.type == MovementType.outgoing
                            ? widget.account.publicAddress
                            : null,
                      );
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Comprovante Oficial'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.hash));
                      _notify('Hash copiado.');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copiar hash'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openUrl(item.explorer),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ver no explorador'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Monta o indicador de estado.
  Widget _buildStatusChip(ChainMovement item) {
    if (item.failed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x22ff5252),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Falhou',
          style: TextStyle(
            color: Color(0xfff87171),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    if (!item.confirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x22ff9800),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xfffbbf24),
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Pendente',
              style: TextStyle(
                color: Color(0xfffbbf24),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x224caf50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Confirmada',
        style: TextStyle(
          color: Color(0xff34d399),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Monta uma linha de detalhes com o estado atual.
  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            height: 1.3,
          ),
        ),
      ],
    ),
  );

  /// Exibe a análise de despesas.
  void _showExpenseAnalytics() {
    final categories = _statement.outgoingByCategory;
    final total = categories.values.fold(BigInt.zero, (a, b) => a + b);
    final isBtc = widget.account.bitcoinChain != null;

    /// Formata o valor para exibição.
    String format(BigInt v) => isBtc ? formatBtc(v) : formatEth(v);
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline, color: colors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Despesas por Tipo de Pagamento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Distribuição de gastos e pagamentos identificados nesta carteira.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (categories.isEmpty || total <= BigInt.zero)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhuma despesa ou saída registrada no período filtrado.',
                    ),
                  ),
                )
              else ...[
                for (final entry in categories.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${format(entry.value)} ${widget.account.symbol} (${((entry.value / total) * 100).toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: total > BigInt.zero
                              ? (entry.value / total).clamp(0.0, 1.0)
                              : 0.0,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total de saídas:',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${format(total)} ${widget.account.symbol}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return WalletScaffold(
      appBar: AppBar(
        title: const Text('Extrato'),
        actions: [
          IconButton(
            tooltip: 'Análise de despesas por tipo',
            onPressed: _showExpenseAnalytics,
            icon: const Icon(Icons.pie_chart_outline),
          ),
          IconButton(
            tooltip: 'Copiar extrato',
            onPressed: () => _copyStatementText(_filteredItems()),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Abrir explorador da carteira',
            onPressed: () => _openUrl(widget.addressExplorer),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _statement,
        builder: (context, _) {
          final items = _filteredItems();
          return RefreshIndicator(
            onRefresh: _statement.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 16),
                            _buildFiltersSection(),
                            const SizedBox(height: 12),
                            _buildSearchBar(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    if (_statement.loading && !_statement.loadedOnce)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Sincronizando extrato com a blockchain...'),
                            ],
                          ),
                        ),
                      )
                    else if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: _statement.all.isEmpty
                                ? 'Nenhuma movimentação registrada'
                                : 'Nenhuma movimentação com este filtro',
                            message: _statement.all.isEmpty
                                ? 'As transações de envio e recebimento desta carteira aparecerão aqui.'
                                : 'Tente alterar o período, dia ou tipo de operação selecionado.',
                            action: _statement.all.isNotEmpty
                                ? TextButton(
                                    onPressed: () {
                                      _statement.setType(null);
                                      _statement.setPeriod(null);
                                      _searchController.clear();
                                    },
                                    child: const Text('Limpar filtros'),
                                  )
                                : null,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverList.separated(
                          itemCount:
                              items.length + (_statement.hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: _statement.loadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton.icon(
                                          onPressed: _statement.loadMore,
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Carregar mais antigas',
                                          ),
                                        ),
                                ),
                              );
                            }
                            return _buildMovementTile(items[index]);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Aplica os filtros ativos à lista exibida no extrato.
  List<ChainMovement> _filteredItems() {
    final base = _statement.visible;
    if (_searchQuery.isEmpty) return base;
    return base.where((item) {
      final contact = _resolveContact(item.counterparty)?.toLowerCase() ?? '';
      final party = item.counterparty?.toLowerCase() ?? '';
      final hash = item.hash.toLowerCase();
      final pType = item.paymentType?.toLowerCase() ?? '';
      return hash.contains(_searchQuery) ||
          party.contains(_searchQuery) ||
          contact.contains(_searchQuery) ||
          pType.contains(_searchQuery);
    }).toList();
  }

  /// Monta `summary card` no fluxo de extrato.
  Widget _buildSummaryCard() {
    final s = _statement.summary;
    final symbol = widget.account.symbol;
    final isBtc = widget.account.bitcoinChain != null;

    /// Formata o valor para exibição.
    String format(BigInt v) => isBtc ? formatBtc(v) : formatEth(v);

    return BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Resumo · ${_statement.period?.label ?? "Todo o período"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              NetworkBadge(
                widget.account.bitcoinChain?.label ?? widget.network.label,
                isTest:
                    widget.account.bitcoinChain == BitcoinChain.testnet4 ||
                    (widget.account.bitcoinChain == null &&
                        widget.network == Network.sepolia),
              ),
            ],
          ),
          const SizedBox(height: 18),
          WalletCardColumns(
            twoColumnWidth: 420,
            children: [
              _summaryStat(
                'Entradas',
                '+${format(s.incoming)} $symbol',
                const Color(0xff91efce),
                Icons.arrow_downward_rounded,
              ),
              _summaryStat(
                'Saídas',
                '−${format(s.outgoing)} $symbol',
                const Color(0xffffbd76),
                Icons.arrow_upward_rounded,
              ),
            ],
          ),
          if (s.fees > BigInt.zero) ...[
            const SizedBox(height: 12),
            Text(
              '${s.count} ${s.count == 1 ? "movimentação" : "movimentações"} · Taxas de rede estimadas: ${format(s.fees)} $symbol',
              style: const TextStyle(color: walletHeroMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// Monta um indicador do resumo do extrato.
  Widget _summaryStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1fffffff),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: walletHeroMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Monta a seção de filtros.
  Widget _buildFiltersSection() {
    final availableCustomTypes = _statement.availablePaymentTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tipo de movimentação (Todos, Entradas, Saídas, Próprias e tipos informados pelo usuário)
        Row(
          children: [
            const Text(
              'Tipo:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'Todos',
                      selected:
                          _statement.type == null &&
                          _statement.customTypeFilter == null,
                      onSelected: () {
                        _statement.setType(null);
                        _statement.setCustomTypeFilter(null);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'Entradas',
                      icon: Icons.arrow_downward,
                      selected:
                          _statement.type == MovementType.incoming &&
                          _statement.customTypeFilter == null,
                      onSelected: () {
                        _statement.setCustomTypeFilter(null);
                        _statement.setType(MovementType.incoming);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'Saídas',
                      icon: Icons.arrow_upward,
                      selected:
                          _statement.type == MovementType.outgoing &&
                          _statement.customTypeFilter == null,
                      onSelected: () {
                        _statement.setCustomTypeFilter(null);
                        _statement.setType(MovementType.outgoing);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'Próprias',
                      icon: Icons.sync_alt,
                      selected:
                          _statement.type == MovementType.self &&
                          _statement.customTypeFilter == null,
                      onSelected: () {
                        _statement.setCustomTypeFilter(null);
                        _statement.setType(MovementType.self);
                      },
                    ),
                    for (final customType in availableCustomTypes) ...[
                      const SizedBox(width: 6),
                      _filterChip(
                        label: customType,
                        icon: Icons.label_outline,
                        selected: _statement.customTypeFilter == customType,
                        onSelected: () {
                          _statement.setType(null);
                          _statement.setCustomTypeFilter(
                            _statement.customTypeFilter == customType
                                ? null
                                : customType,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Período (Todos, Hoje, 7d, 30d, Escolher dia, Personalizado)
        Row(
          children: [
            const Text(
              'Data:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'Tudo',
                      selected: _statement.period == null,
                      onSelected: () => _statement.setPeriod(null),
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'Hoje',
                      selected: _statement.period?.label == 'Hoje',
                      onSelected: () =>
                          _statement.setPeriod(StatementPeriod.lastDays(1)),
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: '7 dias',
                      selected: _statement.period?.label == 'Últimos 7 dias',
                      onSelected: () =>
                          _statement.setPeriod(StatementPeriod.lastDays(7)),
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: '30 dias',
                      selected: _statement.period?.label == 'Últimos 30 dias',
                      onSelected: () =>
                          _statement.setPeriod(StatementPeriod.lastDays(30)),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 14),
                      label: Text(
                        _statement.period != null &&
                                !_statement.period!.label.startsWith(
                                  'Últimos',
                                ) &&
                                _statement.period!.label != 'Hoje'
                            ? _statement.period!.label
                            : 'Escolher dia',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _pickDay,
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.date_range, size: 14),
                      label: const Text(
                        'Intervalo...',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _pickCustomRange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Monta uma opção visual de filtro do extrato.
  Widget _filterChip({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      avatar: icon != null ? Icon(icon, size: 14) : null,
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  /// Monta o campo de busca.
  Widget _buildSearchBar() {
    return SearchBar(
      controller: _searchController,
      hintText: 'Buscar hash, destinatário ou contato...',
      leading: const Icon(Icons.search, size: 20),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      trailing: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            tooltip: 'Limpar busca',
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => _searchController.clear(),
          ),
      ],
    );
  }

  /// Monta `movement tile` no fluxo de extrato.
  Widget _buildMovementTile(ChainMovement item) {
    final colors = Theme.of(context).colorScheme;
    final isIncoming = item.type == MovementType.incoming;
    final isSelf = item.type == MovementType.self;
    final sign = isIncoming ? '+' : '−';
    final contact = _resolveContact(item.counterparty);
    final partyDisplay =
        contact ??
        (item.counterparty != null
            ? shortAddress(item.counterparty!)
            : 'Transação própria');
    final timeDisplay = item.time != null
        ? '${dayLabel(item.time!)} · ${timeLabel(item.time!)}'
        : 'Pendente na rede';

    final Color badgeColor;
    final IconData badgeIcon;
    if (item.failed) {
      badgeColor = Colors.red;
      badgeIcon = Icons.error_outline;
    } else if (!item.confirmed) {
      badgeColor = Colors.orange;
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (isIncoming) {
      badgeColor = colors.brightness == Brightness.dark
          ? const Color(0xff80e2a7)
          : const Color(0xff1b8e4c);
      badgeIcon = Icons.arrow_downward_rounded;
    } else if (isSelf) {
      badgeColor = colors.primary;
      badgeIcon = Icons.sync_alt_rounded;
    } else {
      badgeColor = colors.primary;
      badgeIcon = Icons.arrow_upward_rounded;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => _showMovementDetails(item),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(badgeIcon, color: badgeColor, size: 20),
        ),
        title: Text(
          partyDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            if (item.paymentType case final pType?) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Text(
                timeDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${item.format(item.amount)} ${item.symbol}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isIncoming ? badgeColor : colors.onSurface,
              ),
            ),
            if (!item.confirmed)
              const Text(
                'Pendente',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (item.failed)
              const Text(
                'Revertida',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
