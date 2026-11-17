import 'package:flutter/material.dart';

class WalletPanel extends StatelessWidget {
  /// Inicializa [WalletPanel] com os dados recebidos.
  const WalletPanel({super.key, required this.child});

  final Widget child;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65),
        width: 1.0,
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class AssetMark extends StatelessWidget {
  /// Inicializa [AssetMark] com os dados recebidos.
  const AssetMark(this.symbol, {super.key, this.size = 42});

  final String symbol;
  final double size;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final bitcoin = symbol == 'BTC';
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final primaryColor = bitcoin
        ? const Color(0xfff7931a)
        : const Color(0xff627eea);
    final bgColor = bitcoin
        ? (dark ? const Color(0x33f7931a) : const Color(0xfffff7ed))
        : (dark ? const Color(0x33627eea) : const Color(0xffeef2ff));

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(size / 3.2),
          border: Border.all(
            color: primaryColor.withValues(alpha: dark ? 0.35 : 0.25),
            width: 1.0,
          ),
        ),
        child: Text(
          bitcoin ? '₿' : 'Ξ',
          style: TextStyle(
            color: primaryColor,
            fontSize: size * .52,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class WalletSectionTitle extends StatelessWidget {
  /// Inicializa [WalletSectionTitle] com os dados recebidos.
  const WalletSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class BalanceCard extends StatelessWidget {
  /// Inicializa [BalanceCard] com os dados recebidos.
  const BalanceCard({super.key, required this.child});

  final Widget child;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.0,
      ),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xff0c1322),
          Color(0xff16223e),
          Color(0xff1f2252),
        ],
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // O padrão decorativo é estático: isolado numa camada própria, não
        // é repintado quando o saldo ou os botões mudam.
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BalancePattern()),
          ),
        ),
        Padding(padding: const EdgeInsets.all(22), child: child),
      ],
    ),
  );
}

class _BalancePattern extends CustomPainter {
  /// Inicializa [_BalancePattern] com os dados recebidos.
  const _BalancePattern();

  /// Desenha o gráfico no canvas dentro da área recebida.
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width + 16, 20);
    final line = Paint()
      ..color = const Color(0x18818cf8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var radius = 64.0; radius <= 200; radius += 28) {
      canvas.drawCircle(center, radius, line);
    }
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x286366f1), Color(0x006366f1)],
      ).createShader(Rect.fromCircle(center: center, radius: 220));
    canvas.drawCircle(center, 220, glow);

    // Destaque suave no canto inferior esquerdo
    final bottomGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x1a38bdf8), Color(0x0038bdf8)],
      ).createShader(Rect.fromCircle(center: Offset(0, size.height), radius: 140));
    canvas.drawCircle(Offset(0, size.height), 140, bottomGlow);
  }

  /// Indica se a mudança nos dados exige redesenhar o gráfico.
  @override
  bool shouldRepaint(covariant _BalancePattern oldDelegate) => false;
}

class NetworkBadge extends StatelessWidget {
  /// Inicializa [NetworkBadge] com os dados recebidos.
  const NetworkBadge(this.label, {super.key, required this.isTest});

  final String label;
  final bool isTest;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final dotColor = isTest ? const Color(0xfffbbf24) : const Color(0xff34d399);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Atalho de ação rápida do painel (ícone em destaque + rótulo).
class QuickAction extends StatelessWidget {
  /// Inicializa [QuickAction] com os dados recebidos.
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.7),
            width: 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: enabled
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: enabled ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: enabled ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vazio padronizado (ícone, título e texto de apoio).
class EmptyState extends StatelessWidget {
  /// Inicializa [EmptyState] com os dados recebidos.
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (message case final message?) ...[
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
          ],
          if (action case final action?) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }
}

/// Encurta endereços longos mantendo início e fim visíveis.
String shortAddress(String address, {int head = 8, int tail = 6}) =>
    address.length <= head + tail + 1
    ? address
    : '${address.substring(0, head)}…${address.substring(address.length - tail)}';

/// Rótulo relativo de data ("Hoje", "Ontem" ou dd/mm/aaaa).
String dayLabel(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final current = DateTime(today.year, today.month, today.day);
  final diff = current.difference(day).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';

  /// Formata um número com pelo menos dois dígitos.
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Formata o horário para exibição.
String timeLabel(DateTime date) {
  final local = date.toLocal();

  /// Formata um número com pelo menos dois dígitos.
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// Badge visual padronizado para exibir @username.
class UsernameBadge extends StatelessWidget {
  /// Inicializa [UsernameBadge] com os dados recebidos.
  const UsernameBadge(
    this.username, {
    super.key,
    this.fontSize = 11,
    this.color,
  });

  final String username;
  final double fontSize;
  final Color? color;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        username.startsWith('@') ? username : '@$username',
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Badge visual padronizado para o Identificador Único Soberano (PW-ID).
class UniqueIdBadge extends StatelessWidget {
  /// Inicializa [UniqueIdBadge] com os dados recebidos.
  const UniqueIdBadge(
    this.uniqueId, {
    super.key,
    this.fontSize = 11,
    this.onCopy,
  });

  final String uniqueId;
  final double fontSize;
  final VoidCallback? onCopy;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        uniqueId,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.05,
        ),
      ),
    );

    if (onCopy == null) return badge;

    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(width: 4),
          Icon(Icons.copy, size: fontSize + 1, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Avatar de usuário padronizado com inicial e cores do tema.
class UserAvatar extends StatelessWidget {
  /// Inicializa [UserAvatar] com os dados recebidos.
  const UserAvatar(
    this.name, {
    super.key,
    this.radius = 18,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colors.primaryContainer,
      foregroundColor: foregroundColor ?? colors.onPrimaryContainer,
      child: Text(
        initial,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.9),
      ),
    );
  }
}
