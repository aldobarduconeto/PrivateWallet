import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/gas_tracker_service.dart';
import '../services/system/desktop_window_service.dart';
import '../services/system/header_command_service.dart';
import 'header_quick_search_dialog.dart';

/// Barra de título limpa, moderna e integrada com recursos de produtividade e segurança:
/// - Barra de pesquisa rápida / Command Palette (Spotlight Ctrl+K)
/// - Monitor em tempo real de Gas (Gwei)
/// - Alternador rápido de camuflagem de saldos (Modo Discreto)
/// - Botão de inspeção anti-golpe de endereços
/// - Botão de purga imediata de clipboard
/// - Indicador de rede conectada
/// - Controles nativos de janela sem moldura
class DesktopTitleBar extends StatefulWidget {
  /// Altura padrão da barra de título em pixels.
  final double height;

  /// Título exibido na barra (padrão 'Private Wallet').
  final String title;

  /// Inicializa [DesktopTitleBar].
  const DesktopTitleBar({
    super.key,
    this.height = 40.0,
    this.title = 'Private Wallet',
  });

  /// Abre a paleta de comandos / pesquisa rápida.
  static void openQuickSearch(BuildContext context) {
    HeaderQuickSearchDialog.show(context);
  }

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximizedState();
    HeaderCommandService.instance.startGasMonitoring();
  }

  Future<void> _checkMaximizedState() async {
    final max = await DesktopWindowService.isMaximized();
    if (mounted && max != _isMaximized) {
      setState(() => _isMaximized = max);
    }
  }

  Future<void> _handleToggleMaximize() async {
    await DesktopWindowService.toggleMaximize();
    _checkMaximizedState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = DesktopWindowService.isDesktop;

    final bgColor = theme.scaffoldBackgroundColor;
    final foregroundColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);
    final cmd = HeaderCommandService.instance;

    final isMac = !kIsWeb && Platform.isMacOS;
    final shortcutHint = isMac ? '⌘K' : 'Ctrl+K';

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showFullSearchBar = constraints.maxWidth >= 880;
            final isCompact = constraints.maxWidth < 640;
            final isVeryCompact = constraints.maxWidth < 480;
            final barHeight = isDesktop ? widget.height : 42.0;

            return Container(
              height: barHeight,
              color: bgColor,
              child: Row(
                children: [
                  // Lado Esquerdo: Marca, Logo e Badge de Rede
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: isDesktop ? (_) => DesktopWindowService.startDragging() : null,
                    onDoubleTap: isDesktop ? _handleToggleMaximize : null,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isVeryCompact ? 10.0 : 14.0,
                        right: isVeryCompact ? 6.0 : 10.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: isVeryCompact ? 14 : 15,
                            color: theme.colorScheme.primary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isVeryCompact ? 'PW' : widget.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: foregroundColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge de Rede Conectada
                          ValueListenableBuilder<String>(
                            valueListenable: cmd.networkLabelNotifier,
                            builder: (context, label, _) {
                              final cleanLabel = label.contains('·') ? label.split('·').first.trim() : label;
                              final isTestnet = cleanLabel.toLowerCase().contains('sepolia') ||
                                  cleanLabel.toLowerCase().contains('testnet');
                              final badgeColor = isTestnet ? Colors.amber : Colors.greenAccent.shade400;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 130),
                                      child: Text(
                                        cleanLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Área central: Busca rápida responsiva centralizada e arrasto nativo
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: isDesktop ? (_) => DesktopWindowService.startDragging() : null,
                            onDoubleTap: isDesktop ? _handleToggleMaximize : null,
                            child: const SizedBox(height: double.infinity),
                          ),
                        ),
                        if (showFullSearchBar)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: _HeaderSearchBar(
                              height: 27.0,
                              shortcutHint: shortcutHint,
                              onTap: () => HeaderQuickSearchDialog.show(context),
                            ),
                          ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: isDesktop ? (_) => DesktopWindowService.startDragging() : null,
                            onDoubleTap: isDesktop ? _handleToggleMaximize : null,
                            child: const SizedBox(height: double.infinity),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lado Direito: Ações rápidas integradas
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!showFullSearchBar)
                        _HeaderActionIcon(
                          icon: Icons.search_rounded,
                          tooltip: 'Buscar ($shortcutHint)',
                          color: theme.colorScheme.primary,
                          onTap: () => HeaderQuickSearchDialog.show(context),
                        ),
                      if (!isVeryCompact)
                        // Monitor Rápido de Gas
                        ValueListenableBuilder<GasFeeInfo?>(
                          valueListenable: cmd.gasInfoNotifier,
                          builder: (context, info, _) {
                            final gwei = info?.ethNormalGwei ?? 24;
                            return Tooltip(
                              message: 'Taxa de Gas estimada na rede ($gwei Gwei).\nToque para abrir o Radar de Gas.',
                              child: InkWell(
                                onTap: () => cmd.onOpenGasTracker?.call(),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.25), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.speed, size: 12, color: Colors.deepOrange),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        '$gwei Gwei',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

                      if (!isCompact) ...[
                        // Inspetor Anti-Golpe (Verificar Endereço)
                        _HeaderActionIcon(
                          icon: Icons.manage_search_rounded,
                          tooltip: 'Checar endereço seguro',
                          onTap: () => cmd.onOpenAddressInspector?.call(),
                        ),

                        // Limpar Área de Transferência Imediatamente
                        _HeaderActionIcon(
                          icon: Icons.cleaning_services,
                          tooltip: 'Limpar texto copiado do aparelho',
                          onTap: () => cmd.cleanClipboard(context),
                        ),
                      ],

                      // Alternar Privacidade / Modo Discreto de Saldos
                      ValueListenableBuilder<bool>(
                        valueListenable: cmd.hideBalanceNotifier,
                        builder: (context, hidden, _) {
                          return _HeaderActionIcon(
                            icon: hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            tooltip: hidden ? 'Mostrar saldos' : 'Ocultar saldos',
                            color: hidden ? theme.colorScheme.primary : null,
                            onTap: () => cmd.toggleBalancePrivacy(),
                          );
                        },
                      ),

                      if (isDesktop)
                        _HeaderActionIcon(
                          icon: Icons.settings_outlined,
                          tooltip: 'Configurações',
                          onTap: () => cmd.onOpenSettings?.call(),
                        ),

                      // Controles de Janela Minimalistas (Exibidos apenas em Desktop: Windows, Linux, macOS)
                      if (isDesktop) ...[
                        const SizedBox(width: 6),
                        _WindowButton(
                          tooltip: 'Minimizar',
                          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          onTap: DesktopWindowService.minimize,
                          child: Container(
                            width: 10,
                            height: 1.5,
                            color: foregroundColor,
                          ),
                        ),
                        _WindowButton(
                          tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                          hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          onTap: _handleToggleMaximize,
                          child: _isMaximized
                              ? _RestoreIcon(color: foregroundColor)
                              : _MaximizeIcon(color: foregroundColor),
                        ),
                        _WindowButton(
                          tooltip: 'Fechar',
                          hoverColor: const Color(0xFFE81123),
                          hoverIconColor: Colors.white,
                          onTap: DesktopWindowService.close,
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: foregroundColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Barra de busca rápida central integrada ao cabeçalho.
class _HeaderSearchBar extends StatefulWidget {
  final double height;
  final String shortcutHint;
  final VoidCallback onTap;

  const _HeaderSearchBar({
    required this.height,
    required this.shortcutHint,
    required this.onTap,
  });

  @override
  State<_HeaderSearchBar> createState() => _HeaderSearchBarState();
}

class _HeaderSearchBarState extends State<_HeaderSearchBar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = _hovered
        ? (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.07))
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04));

    final borderColor = _hovered
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscar ferramentas ou ações...',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.shortcutHint,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de ação rápida compacto do cabeçalho.
class _HeaderActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _HeaderActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

/// Ícone clean para maximizar (um retângulo com bordas suaves).
class _MaximizeIcon extends StatelessWidget {
  final Color color;

  const _MaximizeIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Ícone clean para restaurar janela (dois retângulos sobrepostos minimalistas).
class _RestoreIcon extends StatelessWidget {
  final Color color;

  const _RestoreIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 11,
      height: 11,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: color, width: 1.1),
                  right: BorderSide(color: color, width: 1.1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.1),
                borderRadius: BorderRadius.circular(1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão de controle de janela com efeito hover responsivo e visual limpo.
class _WindowButton extends StatefulWidget {
  final Widget child;
  final String tooltip;
  final Color hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onTap;

  const _WindowButton({
    required this.child,
    required this.tooltip,
    required this.hoverColor,
    this.hoverIconColor,
    required this.onTap,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (_isHovered && widget.hoverIconColor != null) {
      content = IconTheme(
        data: IconThemeData(color: widget.hoverIconColor),
        child: content,
      );
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 44,
            height: double.infinity,
            color: _isHovered ? widget.hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
