import 'package:flutter/material.dart';

/// Estimates the space available to text-heavy layouts at the current scale.
double walletLayoutWidth(BuildContext context, double width) {
  const referenceSize = 16.0;
  final scale = MediaQuery.textScalerOf(context).scale(referenceSize);
  return scale > referenceSize ? width * referenceSize / scale : width;
}

class WalletCardColumns extends StatelessWidget {
  const WalletCardColumns({
    super.key,
    required this.children,
    this.twoColumnWidth = 600,
  });

  final List<Widget> children;
  final double twoColumnWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final width = constraints.maxWidth;
      final columns = walletLayoutWidth(context, width) >= twoColumnWidth
          ? 2
          : 1;
      final cardWidth = (width - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in children) SizedBox(width: cardWidth, child: card),
        ],
      );
    },
  );
}

class WalletScaffold extends StatelessWidget {
  const WalletScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.maxContentWidth = 1600,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      top: appBar == null,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SizedBox.expand(child: body),
        ),
      ),
    ),
  );
}

class WalletFloatingActionButton extends StatelessWidget {
  const WalletFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Icon icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final width = walletLayoutWidth(context, MediaQuery.sizeOf(context).width);
    if (width < 380) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: label,
        child: icon,
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
    );
  }
}
