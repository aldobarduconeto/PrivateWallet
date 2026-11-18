import 'package:flutter/material.dart';

import '../models/wallet_account.dart';
import '../services/system/app_permissions_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/wallet_layout.dart';

class WelcomeOnboardingScreen extends StatefulWidget {
  /// Inicializa [WelcomeOnboardingScreen] com os dados recebidos.
  const WelcomeOnboardingScreen({
    super.key,
    this.account,
    this.accountName,
    this.onCompleted,
  });

  final WalletAccount? account;
  final String? accountName;
  final VoidCallback? onCompleted;

  /// Cria o estado local associado ao widget.
  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  final Map<AppPermission, bool> _permissionStatus = {};
  bool _loading = true;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// Verifica as permissões.
  Future<void> _checkPermissions() async {
    for (final perm in AppPermission.values) {
      final granted = await AppPermissionsService.isGranted(perm);
      _permissionStatus[perm] = granted;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Solicita `permission` no fluxo de welcome onboarding.
  Future<void> _requestPermission(AppPermission perm) async {
    final granted = await AppPermissionsService.request(perm);
    if (perm == AppPermission.background) {
      await AppPermissionsService.requestBatteryOptimization();
    }
    if (mounted) {
      setState(() {
        _permissionStatus[perm] = granted;
      });
    }
  }

  /// Solicita `all permissions` no fluxo de welcome onboarding.
  Future<void> _requestAllPermissions() async {
    for (final perm in AppPermission.values) {
      final granted = await AppPermissionsService.request(perm);
      _permissionStatus[perm] = granted;
    }
    await AppPermissionsService.requestBatteryOptimization();
    if (mounted) setState(() {});
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return WalletScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ícone de Boas-Vindas
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/wallet_icon.png',
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bem-vindo à Private Wallet!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sua conta "${widget.account?.name ?? widget.accountName ?? 'Sua Carteira'}" foi criada com sucesso sob 100% de autocustódia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card de Destaque das Funcionalidades
                  Card(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(WalletRadius.medium),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'FUNCIONALIDADES DA SUA CARTEIRA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FeatureRow(
                            icon: Icons.all_inclusive,
                            title: 'Suporte Multi-Moeda Unificado',
                            description: 'Gerencie Ethereum e Bitcoin SegWit nativo simultaneamente a partir da mesma semente.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.shield_outlined,
                            title: 'Autocustódia e Soberania Total',
                            description: 'As chaves privadas nunca saem deste aparelho. Sem cadastros, sem KYC e sem dados de terceiros.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.savings_outlined,
                            title: 'Cofres & Gavetas de Reserva',
                            description: 'Separe saldos para metas e reserva patrimonial com trava mental (não rende juros).',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.receipt_long_outlined,
                            title: 'Comprovante Bancário Cripto',
                            description: 'Emita comprovantes oficiais formatados com TXID e salve em arquivo de texto no seu dispositivo.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.autorenew,
                            title: 'Débitos Recorrentes & Cobrança PDV',
                            description: 'Automatize pagamentos periódicos em cripto e cobre valores fixos em moeda fiduciária com QR Code instantâneo.',
                          ),
                          const SizedBox(height: 12),
                          _FeatureRow(
                            icon: Icons.security,
                            title: 'Inspetor Anti-Golpe & Privacidade',
                            description: 'Auditoria de endereços pré-envio, escudo determinístico de emojis e modo discreto para uso seguro em locais públicos.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Seção de Permissões do Sistema
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERMISSÕES DO SISTEMA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Autorize os recursos para a melhor experiência:',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _requestAllPermissions,
                        child: const Text('Autorizar todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    for (final perm in AppPermission.values)
                      _PermissionTile(
                        permission: perm,
                        granted: _permissionStatus[perm] ?? false,
                        onRequest: () => _requestPermission(perm),
                      ),
                  ],

                  const SizedBox(height: 28),

                  // Botão de Início
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        widget.onCompleted ??
                        () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'Acessar Minha Carteira',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  /// Inicializa [_FeatureRow] com os dados recebidos.
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  /// Inicializa [_PermissionTile] com os dados recebidos.
  const _PermissionTile({
    required this.permission,
    required this.granted,
    required this.onRequest,
  });

  final AppPermission permission;
  final bool granted;
  final VoidCallback onRequest;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: granted
                    ? const Color(0x2210b981)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getPermissionIcon(permission),
                size: 20,
                color: granted
                    ? const Color(0xff10b981)
                    : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    permission.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (granted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x2210b981),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: Color(0xff10b981)),
                    SizedBox(width: 4),
                    Text(
                      'Permitido',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xff10b981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onRequest,
                child: const Text('Autorizar'),
              ),
          ],
        ),
      ),
    );
  }

  /// Retorna `permission icon` no fluxo de welcome onboarding.
  IconData _getPermissionIcon(AppPermission perm) => switch (perm) {
    AppPermission.notification => Icons.notifications_active_outlined,
    AppPermission.storage => Icons.folder_outlined,
    AppPermission.background => Icons.battery_charging_full_outlined,
    AppPermission.network => Icons.wifi_outlined,
  };
}
