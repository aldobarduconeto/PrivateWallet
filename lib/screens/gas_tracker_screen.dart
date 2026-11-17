import 'package:flutter/material.dart';

import '../services/gas_tracker_service.dart';

class GasTrackerScreen extends StatefulWidget {
  /// Inicializa [GasTrackerScreen] com os dados recebidos.
  const GasTrackerScreen({super.key});

  /// Cria o estado local associado ao widget.
  @override
  State<GasTrackerScreen> createState() => _GasTrackerScreenState();
}

class _GasTrackerScreenState extends State<GasTrackerScreen> {
  final _service = const GasTrackerService();
  final _targetGweiController = TextEditingController();

  GasFeeInfo? _info;
  int? _savedTarget;
  bool _loading = true;
  String _selectedChain = 'ETH'; // 'ETH' ou 'BTC'

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _targetGweiController.dispose();
    super.dispose();
  }

  /// Carrega os dados necessários para apresentar a tela.
  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await _service.fetchCurrentGas();
    final target = await _service.loadGasTargetGwei();
    if (mounted) {
      setState(() {
        _info = info;
        _savedTarget = target;
        if (target != null) {
          _targetGweiController.text = target.toString();
        }
        _loading = false;
      });
    }
  }

  /// Salva o alerta de gas.
  Future<void> _saveGasAlert() async {
    final text = _targetGweiController.text.trim();
    final target = int.tryParse(text);
    await _service.saveGasTargetGwei(target);
    setState(() => _savedTarget = target);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target != null
                ? 'Alarme salvo! Você será avisado quando o Gas cair para <= $target Gwei.'
                : 'Alarme de Gas desativado.',
          ),
        ),
      );
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final info = _info;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otimizador de Gas & Mempool'),
        actions: [
          IconButton(
            tooltip: 'Atualizar Taxas',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading || info == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;

                final tierCards = _selectedChain == 'ETH'
                    ? [
                        _buildTierCard(
                          title: 'Econômica (Baixa)',
                          subtitle: 'Tempo estimado: ~3 a 5 min',
                          rate: '${info.ethSlowGwei} Gwei',
                          costBrl:
                              '≈ R\$ ${info.ethCostBrl(info.ethSlowGwei).toStringAsFixed(2)}',
                          color: Colors.green,
                          icon: Icons.savings_outlined,
                        ),
                        _buildTierCard(
                          title: 'Padrão (Recomendada)',
                          subtitle: 'Tempo estimado: ~30 segundos',
                          rate: '${info.ethNormalGwei} Gwei',
                          costBrl:
                              '≈ R\$ ${info.ethCostBrl(info.ethNormalGwei).toStringAsFixed(2)}',
                          color: Colors.blue,
                          icon: Icons.check_circle_outline,
                          isRecommended: true,
                        ),
                        _buildTierCard(
                          title: 'Prioridade Alta',
                          subtitle: 'Tempo estimado: ~12s (próximo bloco)',
                          rate: '${info.ethFastGwei} Gwei',
                          costBrl:
                              '≈ R\$ ${info.ethCostBrl(info.ethFastGwei).toStringAsFixed(2)}',
                          color: Colors.orange,
                          icon: Icons.flash_on,
                        ),
                      ]
                    : [
                        _buildTierCard(
                          title: 'Baixa Prioridade',
                          subtitle:
                              'Tempo estimado: ~1 a 2h (próximos blocos)',
                          rate: '${info.btcSlowSatVb} sat/vB',
                          costBrl:
                              '≈ R\$ ${info.btcCostBrl(info.btcSlowSatVb).toStringAsFixed(2)}',
                          color: Colors.green,
                          icon: Icons.savings_outlined,
                        ),
                        _buildTierCard(
                          title: 'Média (Recomendada)',
                          subtitle: 'Tempo estimado: ~20 a 30 minutos',
                          rate: '${info.btcNormalSatVb} sat/vB',
                          costBrl:
                              '≈ R\$ ${info.btcCostBrl(info.btcNormalSatVb).toStringAsFixed(2)}',
                          color: Colors.blue,
                          icon: Icons.check_circle_outline,
                          isRecommended: true,
                        ),
                        _buildTierCard(
                          title: 'Alta Prioridade',
                          subtitle: 'Tempo estimado: Próximo bloco (~10 min)',
                          rate: '${info.btcFastSatVb} sat/vB',
                          costBrl:
                              '≈ R\$ ${info.btcCostBrl(info.btcFastSatVb).toStringAsFixed(2)}',
                          color: Colors.orange,
                          icon: Icons.flash_on,
                        ),
                      ];

                final alarmCard = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Alarme de Gas Econômico',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seja notificado quando as taxas caírem para enviar pelo menor preço.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetGweiController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Avisar se o Gas cair para (Gwei)',
                                suffixText: 'Gwei',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: _saveGasAlert,
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Salvar'),
                          ),
                        ],
                      ),
                      if (_savedTarget != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Alarme ativo para <= $_savedTarget Gwei.',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                _targetGweiController.clear();
                                _saveGasAlert();
                              },
                              child: const Text(
                                'Desativar',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );

                final tipsCard = Container(
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Dica de Economia Soberana',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• As taxas de rede variam com o tráfego global on-chain.\n'
                        '• Domingos e madrugadas (01h às 06h UTC-3) chegam a ter taxas até 70% menores do que o horário comercial em dias úteis.\n'
                        '• Para pagamentos não urgentes, sempre use a prioridade Econômica.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );

                return RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 400 ? 12 : 20,
                          vertical: 16,
                        ),
                        children: [
                          // Seletor de Rede
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'ETH',
                                label: Text('Ethereum (Gwei)'),
                                icon: Icon(Icons.toll),
                              ),
                              ButtonSegment(
                                value: 'BTC',
                                label: Text('Bitcoin (sat/vB)'),
                                icon: Icon(Icons.currency_bitcoin),
                              ),
                            ],
                            selected: {_selectedChain},
                            onSelectionChanged: (set) =>
                                setState(() => _selectedChain = set.first),
                          ),
                          const SizedBox(height: 16),

                          // Banner de Tráfego e Recomendação
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.speed, color: colors.primary, size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Congestionamento da Rede: ${info.congestionLevel}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        info.recommendation,
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
                          const SizedBox(height: 18),

                          // Cards de Velocidade Responsivos
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < tierCards.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 14),
                                  Expanded(child: tierCards[i]),
                                ],
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < tierCards.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  tierCards[i],
                                ],
                              ],
                            ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Alarme & Dicas Lado a Lado no Desktop / Tablet
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: alarmCard),
                                const SizedBox(width: 18),
                                Expanded(child: tipsCard),
                              ],
                            )
                          else ...[
                            alarmCard,
                            const SizedBox(height: 16),
                            tipsCard,
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Monta `tier card` no fluxo de monitor de gas.
  Widget _buildTierCard({
    required String title,
    required String subtitle,
    required String rate,
    required String costBrl,
    required Color color,
    required IconData icon,
    bool isRecommended = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRecommended
            ? colors.primaryContainer.withValues(alpha: 0.25)
            : colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecommended
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: 0.4),
          width: isRecommended ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IDEAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
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
                rate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                costBrl,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
