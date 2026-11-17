import 'package:flutter/material.dart';

import '../models/wallet_account.dart';
import '../services/system/privacy_stealth_service.dart';

class PrivacyStealthScreen extends StatefulWidget {
  /// Inicializa [PrivacyStealthScreen] com os dados recebidos.
  const PrivacyStealthScreen({
    super.key,
    required this.account,
    required this.hasBiometrics,
    required this.lockOnBackground,
    this.onStealthModeChanged,
  });

  final WalletAccount account;
  final bool hasBiometrics;
  final bool lockOnBackground;
  final ValueChanged<bool>? onStealthModeChanged;

  /// Cria o estado local associado ao widget.
  @override
  State<PrivacyStealthScreen> createState() => _PrivacyStealthScreenState();
}

class _PrivacyStealthScreenState extends State<PrivacyStealthScreen> {
  final _service = const PrivacyStealthService();

  bool _loading = true;
  bool _stealthMode = false;
  bool _decoyMode = false;
  bool _maskAddresses = false;
  PrivacyAuditScore? _audit;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Carrega os dados necessários para apresentar a tela.
  Future<void> _load() async {
    setState(() => _loading = true);
    final stealth = await _service.isStealthModeActive();
    final decoy = await _service.isDecoyModeActive();
    final mask = await _service.isMaskAddressesActive();
    final audit = await _service.runPrivacyAudit(
      hasBiometrics: widget.hasBiometrics,
      isWatchOnly: !widget.account.canSign,
      lockOnBackground: widget.lockOnBackground,
    );

    if (mounted) {
      setState(() {
        _stealthMode = stealth;
        _decoyMode = decoy;
        _maskAddresses = mask;
        _audit = audit;
        _loading = false;
      });
    }
  }

  /// Alterna o modo discreto.
  Future<void> _toggleStealth(bool val) async {
    await _service.setStealthMode(val);
    setState(() => _stealthMode = val);
    widget.onStealthModeChanged?.call(val);
    await _load();
  }

  /// Alterna a apresentação dos dados de demonstração.
  Future<void> _toggleDecoy(bool val) async {
    await _service.setDecoyMode(val);
    setState(() => _decoyMode = val);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? 'Modo Isca (Decoy) Ativado: Exibe dados de segurança para situações de coação.'
                : 'Modo Isca desativado.',
          ),
        ),
      );
    }
    await _load();
  }

  /// Alterna a ocultação visual dos endereços.
  Future<void> _toggleMask(bool val) async {
    await _service.setMaskAddresses(val);
    setState(() => _maskAddresses = val);
    await _load();
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final audit = _audit;

    return Scaffold(
      appBar: AppBar(title: const Text('Central de Privacidade & Camuflagem')),
      body: _loading || audit == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                // Card de Pontuação de Privacidade
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: audit.score / 100.0,
                              strokeWidth: 6,
                              backgroundColor: colors.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                audit.score >= 80
                                    ? Colors.green
                                    : (audit.score >= 50
                                          ? Colors.orange
                                          : Colors.red),
                              ),
                            ),
                          ),
                          Text(
                            '${audit.score}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nível de Blindagem de Privacidade',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              audit.score >= 80
                                  ? 'Sua carteira possui excelente proteção contra bisbilhoteiros e vazamento de dados.'
                                  : 'Existem configurações recomendadas para melhorar sua privacidade em público.',
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
                const SizedBox(height: 20),

                // Controles de Privacidade
                const Text(
                  'Camuflagem e Proteção em Público',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.visibility_off_outlined,
                    color: Colors.blue,
                  ),
                  title: const Text('Modo Discreto / Camuflagem'),
                  subtitle: const Text(
                    'Oculta saldos e valores monetários (••••••) ao abrir o app em locais públicos para evitar curiosos.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _stealthMode,
                  onChanged: _toggleStealth,
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.shield_outlined,
                    color: Colors.purple,
                  ),
                  title: const Text('Ofuscar Endereços Públicos'),
                  subtitle: const Text(
                    'Abrevia trechos dos endereços na tela para impedir filmagens por câmeras ou olhares por cima do ombro.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _maskAddresses,
                  onChanged: _toggleMask,
                ),
                const Divider(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.security, color: Colors.amber),
                  title: const Text('Modo Isca / Coação (Decoy Mode)'),
                  subtitle: const Text(
                    'Exibe uma carteira secundária fictícia sem revelar seus fundos reais caso seja forçado a abrir o app.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _decoyMode,
                  onChanged: _toggleDecoy,
                ),
                const SizedBox(height: 20),

                // Diagnóstico da Auditoria
                const Text(
                  'Diagnóstico de Proteção',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),

                for (final check in audit.passedChecks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            check,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (audit.improvementTips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final tip in audit.improvementTips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 20),
                // Princípios da Soberania
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_person_outlined,
                            color: Colors.teal,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pilares da Autocustódia Soberana',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• "Not your keys, not your coins": Suas chaves privadas nunca saem do seu dispositivo sem a sua permissão.\n'
                        '• Ao transacionar em locais com câmeras ou pessoas próximas, mantenha o Modo Discreto ativado.\n'
                        '• Nunca fotografe ou envie sua chave de recuperação por mensageiros ou e-mail.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          height: 1.4,
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
}
