import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_state.dart';
import '../models/wallet_activity.dart';
import '../services/blockchain/blockchain_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/wallet_widgets.dart';

class WalletActivityScreen extends StatefulWidget {
  /// Inicializa [WalletActivityScreen] com os dados recebidos.
  const WalletActivityScreen({
    super.key,
    required this.entries,
    required this.network,
    required this.addressExplorer,
    this.contactName,
    this.purchases = false,
    this.canPurchase = false,
  });

  final List<WalletActivity> entries;
  final String network;
  final Uri addressExplorer;
  final bool purchases;
  final bool canPurchase;

  /// Resolve o nome salvo na agenda para um endereço de destino.
  final String? Function(String address)? contactName;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletActivityScreen> createState() => _WalletActivityScreenState();
}

class _WalletActivityScreenState extends State<WalletActivityScreen> {
  final _search = TextEditingController();

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Abre o histórico de atividades da carteira.
  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Report an unavailable browser through the same UI path.
    }
    _notify('Não foi possível abrir o explorador.');
  }

  /// Resolve o nome de contato ou o endereço exibido para o destinatário.
  String _recipient(WalletActivity entry) =>
      widget.contactName?.call(entry.recipient) ??
      shortAddress(entry.recipient);

  /// Monta os detalhes com o estado atual.
  Future<void> _details(WalletActivity entry) {
    final status = BlockchainService().status(entry);
    final contact = widget.contactName?.call(entry.recipient);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${entry.format(entry.amount)} ${entry.symbol}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${dayLabel(entry.created)} · ${timeLabel(entry.created)} · ${widget.network}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<TransactionState>(
                future: status,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: const Icon(Icons.info_outline, size: 18),
                      label: Text(
                        snapshot.data?.label ??
                            'Status indisponível. Tente novamente.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _detail(
                'Para',
                contact == null
                    ? entry.recipient
                    : '$contact\n${entry.recipient}',
              ),
              _detail(
                'Taxa prevista',
                '${entry.format(entry.fee)} ${entry.symbol}',
              ),
              _detail('Hash', entry.hash),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: entry.hash));
                      _notify('Hash copiado.');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copiar hash'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _open(entry.explorer),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Explorador'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe os dados de uma atividade selecionada.
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(fontFamily: 'monospace', height: 1.4),
        ),
      ],
    ),
  );

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.entries
        .where(
          (entry) =>
              query.isEmpty ||
              entry.recipient.toLowerCase().contains(query) ||
              entry.hash.toLowerCase().contains(query) ||
              (widget.contactName?.call(entry.recipient)?.toLowerCase() ?? '')
                  .contains(query),
        )
        .toList();
    // Agrupa por dia mantendo a ordem (mais recentes primeiro).
    final groups = <String, List<WalletActivity>>{};
    for (final entry in visible) {
      groups.putIfAbsent(dayLabel(entry.created), () => []).add(entry);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de envios'),
        actions: [
          IconButton(
            tooltip: 'Movimentações na blockchain',
            onPressed: () => _open(widget.addressExplorer),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: _summary()),
              ),
              if (widget.entries.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: SearchBar(
                      controller: _search,
                      hintText: 'Buscar destino, contato ou hash',
                      leading: const Icon(Icons.search),
                      elevation: const WidgetStatePropertyAll(0),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: widget.entries.isEmpty
                          ? 'Nenhum envio registrado nesta carteira e rede.'
                          : 'Nenhum envio encontrado',
                      message: widget.entries.isEmpty
                          ? 'Recebimentos e envios feitos em outros aparelhos aparecem no explorador.'
                          : 'Tente outro termo de busca.',
                      action: OutlinedButton.icon(
                        onPressed: () => _open(widget.addressExplorer),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Movimentações na blockchain'),
                      ),
                    ),
                  ),
                )
              else
                for (final group in groups.entries) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        group.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: group.value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _tile(group.value[index]),
                    ),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  /// Monta o resumo com o estado atual.
  Widget _summary() {
    final entries = widget.entries;
    final symbol = entries.isEmpty ? '' : ' ${entries.first.symbol}';
    final total = entries.fold(BigInt.zero, (sum, entry) => sum + entry.amount);
    final fees = entries.fold(BigInt.zero, (sum, entry) => sum + entry.fee);

    /// Formata o valor para exibição.
    String format(BigInt value) =>
        entries.isEmpty ? '0' : entries.first.format(value);
    return BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkBadge(widget.network, isTest: false),
          const SizedBox(height: 16),
          const Text(
            'Total enviado deste aparelho',
            style: TextStyle(color: walletHeroMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${format(total)}$symbol',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${entries.length} ${entries.length == 1 ? 'envio' : 'envios'} · '
            'taxas previstas ${format(fees)}$symbol',
            style: const TextStyle(color: walletHeroMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Monta a linha de uma atividade no histórico.
  Widget _tile(WalletActivity entry) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_upward_rounded, color: colors.primary),
        ),
        title: Text(
          _recipient(entry),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          timeLabel(entry.created),
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        trailing: Text(
          '−${entry.format(entry.amount)} ${entry.symbol}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        onTap: () => _details(entry),
      ),
    );
  }
}
