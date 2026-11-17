import 'package:flutter/material.dart';

import '../models/market_asset.dart';
import '../services/crypto_market_service.dart';

class CryptoMarketScreen extends StatefulWidget {
  /// Inicializa [CryptoMarketScreen] com os dados recebidos.
  const CryptoMarketScreen({super.key});

  /// Cria o estado local associado ao widget.
  @override
  State<CryptoMarketScreen> createState() => _CryptoMarketScreenState();
}

class _CryptoMarketScreenState extends State<CryptoMarketScreen> {
  final _service = const CryptoMarketService();
  List<MarketAsset> _assets = [];
  List<PriceAlert> _alerts = [];
  bool _loading = true;
  String _currency = 'BRL'; // 'BRL' ou 'USD'

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Carrega os dados.
  Future<void> _loadData() async {
    setState(() => _loading = true);
    final assets = await _service.fetchAssets();
    final alerts = await _service.loadAlerts();
    await _service.checkAndTriggerAlerts(assets);
    if (mounted) {
      setState(() {
        _assets = assets;
        _alerts = alerts;
        _loading = false;
      });
    }
  }

  /// Abre o diálogo de novo alerta.
  Future<void> _openCreateAlertDialog([String? initialSymbol]) async {
    final asset = _assets.firstWhere(
      (a) => a.symbol == (initialSymbol ?? 'BTC'),
      orElse: () => _assets.first,
    );

    var selectedSymbol = asset.symbol;
    var isAbove = true;
    final priceController = TextEditingController(
      text: asset.priceBrl.toStringAsFixed(2),
    );

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final curAsset = _assets.firstWhere(
            (a) => a.symbol == selectedSymbol,
          );
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_alert_outlined),
                SizedBox(width: 8),
                Text('Criar Alerta de Preço'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Selecione a Criptomoeda:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSymbol,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _assets
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.symbol,
                            child: Row(
                              children: [
                                Icon(a.icon, color: a.color, size: 20),
                                const SizedBox(width: 8),
                                Text('${a.name} (${a.symbol})'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedSymbol = val;
                          final newAsset = _assets.firstWhere(
                            (a) => a.symbol == val,
                          );
                          priceController.text = newAsset.priceBrl
                              .toStringAsFixed(2);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preço atual: R\$ ${curAsset.priceBrl.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Condição do Alerta:'),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Subir acima de'),
                        icon: Icon(Icons.trending_up),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Cair abaixo de'),
                        icon: Icon(Icons.trending_down),
                      ),
                    ],
                    selected: {isAbove},
                    onSelectionChanged: (set) =>
                        setDialogState(() => isAbove = set.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço alvo em R\$ (BRL)',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final target = double.tryParse(
                    priceController.text.replaceAll(',', '.'),
                  );
                  if (target != null && target > 0) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Salvar Alerta'),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      final target = double.parse(priceController.text.replaceAll(',', '.'));
      final newAlert = PriceAlert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: selectedSymbol,
        targetPriceBrl: target,
        isAbove: isAbove,
        createdAt: DateTime.now(),
      );
      await _service.addAlert(newAlert);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alerta criado para $selectedSymbol quando ${isAbove ? "subir acima" : "cair abaixo"} de R\$ ${target.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercado & Alertas'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currency = _currency == 'BRL' ? 'USD' : 'BRL';
              });
            },
            child: Text(
              _currency,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateAlertDialog(),
        icon: const Icon(Icons.add_alert),
        label: const Text('Novo Alerta'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final quotesSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cotações em Tempo Real',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Moeda: $_currency',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final asset in _assets) _buildAssetCard(asset),
                  ],
                );

                final alertsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alertas de Preço',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_alerts.where((a) => a.isActive).length} ativos',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_alerts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 40,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nenhum alerta de preço configurado.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Crie alertas para ser avisado quando uma criptomoeda atingir o valor desejado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final alert in _alerts) _buildAlertTile(alert),
                  ],
                );

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth < 400 ? 12 : 20,
                          16,
                          constraints.maxWidth < 400 ? 12 : 20,
                          80,
                        ),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 6, child: quotesSection),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 5, child: alertsSection),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  quotesSection,
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  alertsSection,
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Monta `asset card` no fluxo de mercado.
  Widget _buildAssetCard(MarketAsset asset) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final isBrl = _currency == 'BRL';
    final priceStr = isBrl
        ? 'R\$ ${asset.priceBrl.toStringAsFixed(asset.priceBrl < 10 ? 3 : 2)}'
        : '\$ ${asset.priceUsd.toStringAsFixed(asset.priceUsd < 10 ? 3 : 2)}';
    final highStr = isBrl
        ? 'R\$ ${asset.high24hBrl.toStringAsFixed(asset.high24hBrl < 10 ? 2 : 0)}'
        : '\$ ${(asset.high24hBrl / 5.56).toStringAsFixed(0)}';
    final lowStr = isBrl
        ? 'R\$ ${asset.low24hBrl.toStringAsFixed(asset.low24hBrl < 10 ? 2 : 0)}'
        : '\$ ${(asset.low24hBrl / 5.56).toStringAsFixed(0)}';

    final changeColor = asset.isPositive
        ? (dark ? const Color(0xff34d399) : const Color(0xff059669))
        : (dark ? const Color(0xfff87171) : const Color(0xffdc2626));
    final changeBg = asset.isPositive
        ? (dark ? const Color(0x2834d399) : const Color(0xffdcfce7))
        : (dark ? const Color(0x28f87171) : const Color(0xfffee2e2));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: asset.color.withValues(alpha: 0.16),
                  child: Icon(asset.icon, color: asset.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '${asset.symbol} · Cap: R\$ ${asset.marketCapBrl}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: changeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${asset.isPositive ? "+" : ""}${asset.change24h.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: changeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '24h Mín: $lowStr  |  Máx: $highStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openCreateAlertDialog(asset.symbol),
                  icon: const Icon(Icons.notification_add_outlined, size: 16),
                  label: const Text('Alerta', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Monta `alert tile` no fluxo de mercado.
  Widget _buildAlertTile(PriceAlert alert) {
    final colors = Theme.of(context).colorScheme;
    final asset = _assets.firstWhere(
      (a) => a.symbol.toUpperCase() == alert.symbol.toUpperCase(),
      orElse: () => _assets.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.isActive
            ? colors.surfaceContainerHighest.withValues(alpha: 0.4)
            : colors.surfaceContainerLow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isActive
              ? colors.outlineVariant.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert.isAbove ? Icons.arrow_upward : Icons.arrow_downward,
            color: alert.isAbove ? Colors.green : Colors.red,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alert.symbol} ${alert.isAbove ? ">=" : "<="} R\$ ${alert.targetPriceBrl.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: alert.isActive
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  alert.triggeredAt != null
                      ? 'Disparado em: ${alert.triggeredAt!.day}/${alert.triggeredAt!.month} às ${alert.triggeredAt!.hour}:${alert.triggeredAt!.minute.toString().padLeft(2, "0")}'
                      : 'Preço atual: R\$ ${asset.priceBrl.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: alert.isActive,
            onChanged: (val) async {
              await _service.toggleAlert(alert.id, val);
              await _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: colors.error,
            onPressed: () async {
              await _service.removeAlert(alert.id);
              await _loadData();
            },
          ),
        ],
      ),
    );
  }
}
