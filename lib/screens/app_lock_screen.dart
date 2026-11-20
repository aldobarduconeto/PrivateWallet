import 'dart:async';
import 'package:flutter/material.dart';

import '../services/system/auth_protection_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/wallet_layout.dart';

class AppLockScreen extends StatefulWidget {
  /// Inicializa [AppLockScreen] com os dados recebidos.
  const AppLockScreen({
    super.key,
    required this.onUnlocked,
    this.isDesktopLock = false,
  });

  final VoidCallback onUnlocked;
  final bool isDesktopLock;

  /// Cria o estado local associado ao widget.
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;
  bool _authenticating = false;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _hasMasterPass = false;
  bool _showPinKeypad = false;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _checkLockoutAndSetup();
    if (AuthProtectionService.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometrics();
      });
    }
  }

  /// Verifica se há bloqueio por taxa de erros e se há senha mestre cadastrada.
  Future<void> _checkLockoutAndSetup() async {
    final remaining = await AuthProtectionService.getLockoutRemainingSeconds();
    final hasPass = await AuthProtectionService.hasMasterPassword();
    if (mounted) {
      setState(() {
        _lockoutSeconds = remaining;
        _hasMasterPass = hasPass;
      });
      if (remaining > 0) _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSeconds > 1) {
          _lockoutSeconds--;
        } else {
          _lockoutSeconds = 0;
          _error = null;
          timer.cancel();
        }
      });
    });
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  /// Aciona biometria no mobile.
  Future<void> _triggerBiometrics() async {
    if (_authenticating || _lockoutSeconds > 0) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final success = await AuthProtectionService.authenticateBiometrics(
        title: 'Desbloquear Private Wallet',
        subtitle: 'Confirme sua biometria ou Face ID',
      );
      if (!mounted) return;
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Autenticação biométrica não reconhecida.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro na biometria: $e');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  /// Desbloqueia com senha mestra ou PIN (com suporte a PIN de Coação).
  Future<void> _unlockWithPassword() async {
    if (_lockoutSeconds > 0) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Digite o PIN ou senha mestra.');
      return;
    }

    setState(() {
      _authenticating = true;
      _error = null;
    });

    final result = await AuthProtectionService.verifyCredentials(password);
    if (!mounted) return;

    if (result.isSuccess || result.isDuress) {
      widget.onUnlocked();
    } else if (result.isRateLimited) {
      setState(() {
        _lockoutSeconds = result.remainingLockoutSeconds;
        _error = result.message;
        _authenticating = false;
      });
      _startLockoutTimer();
    } else {
      setState(() {
        _error = result.message ?? 'PIN ou senha incorreta.';
        _authenticating = false;
      });
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: WalletScaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ícone de Segurança Soberana
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 46,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Private Wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Autenticação Criptográfica Soberana',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sem e-mail, sem telefone, sem servidores. Seu cofre é 100% local.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Banner de Bloqueio por Força Bruta (Rate Limiting)
                  if (_lockoutSeconds > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.timer_off_outlined, color: Colors.red, size: 28),
                          const SizedBox(height: 8),
                          const Text(
                            'Proteção Anti-Força Bruta Ativa',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Muitas tentativas falhas consecutivas.\nAguarde $_lockoutSeconds segundos antes de tentar novamente.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Campo de Senha Mestra / PIN
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: _lockoutSeconds == 0,
                    autofocus: widget.isDesktopLock || !AuthProtectionService.isMobile,
                    onSubmitted: (_) => _unlockWithPassword(),
                    decoration: InputDecoration(
                      labelText: _hasMasterPass ? 'PIN ou Senha Mestra' : 'Senha do Aplicativo',
                      prefixIcon: const Icon(Icons.password_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton.icon(
                      icon: Icon(_showPinKeypad ? Icons.keyboard : Icons.dialpad_rounded, size: 18),
                      label: Text(_showPinKeypad ? 'Usar Teclado Alfanumérico' : 'Usar Teclado Numérico (PIN)'),
                      onPressed: () => setState(() => _showPinKeypad = !_showPinKeypad),
                    ),
                  ),

                  if (_showPinKeypad) ...[
                    const SizedBox(height: 12),
                    _buildPinKeypad(colors),
                    const SizedBox(height: 12),
                  ],

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: (_authenticating || _lockoutSeconds > 0)
                        ? null
                        : _unlockWithPassword,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Desbloquear Carteira'),
                  ),

                  // Atalho de Biometria no Mobile
                  if (AuthProtectionService.isMobile) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: (_authenticating || _lockoutSeconds > 0)
                          ? null
                          : _triggerBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 22),
                      label: const Text('Autenticar com Biometria / Face ID'),
                    ),
                  ],

                  if (_error != null && _lockoutSeconds == 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Text(
                    '🛡️ Autocustódia Soberana · Protegido por criptografia matemática local.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: walletHeroMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  Widget _buildPinKeypad(ColorScheme colors) {
    Widget pinBtn(String label, {IconData? icon, VoidCallback? onTap}) {
      return Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                if (_lockoutSeconds > 0) return;
                setState(() {
                  _passwordController.text += label;
                });
                if (_passwordController.text.length == 4 ||
                    _passwordController.text.length == 6) {
                  _unlockWithPassword();
                }
              },
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 22, color: colors.onSurface)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: pinBtn('1')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('2')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('3')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: pinBtn('4')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('5')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('6')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: pinBtn('7')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('8')),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('9')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: pinBtn(
                '',
                icon: Icons.backspace_outlined,
                onTap: () {
                  if (_passwordController.text.isNotEmpty) {
                    setState(() {
                      _passwordController.text = _passwordController.text
                          .substring(0, _passwordController.text.length - 1);
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: pinBtn('0')),
            const SizedBox(width: 10),
            Expanded(
              child: pinBtn(
                '',
                icon: Icons.check_circle_outline,
                onTap: _unlockWithPassword,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
