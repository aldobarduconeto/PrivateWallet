import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../models/app_contrast_theme.dart';

const walletInk = Color(0xff17213a);
const walletHeroMuted = Color(0xffd1dcf5);

/// Raios padronizados do design system.
abstract final class WalletRadius {
  static const small = 12.0;
  static const medium = 18.0;
  static const large = 24.0;
}

/// Cria o tema Material de acordo com o brilho e o contraste escolhidos.
ThemeData walletTheme(
  Brightness brightness, {
  AppContrastTheme contrastTheme = AppContrastTheme.standard,
}) {
  final dark = brightness == Brightness.dark;
  final isHighContrast = contrastTheme == AppContrastTheme.highContrast;

  Color canvas;
  Color surface;
  Color primary;
  Color onSurface;
  Color onSurfaceVariant;
  Color outlineVariant;
  Color secondaryContainer;
  Color surfaceContainerHighest;

  if (isHighContrast) {
    if (dark) {
      canvas = const Color(0xff000000); // Preto puro OLED
      surface = const Color(0xff080b11);
      primary = const Color(0xfff8fafc);
      onSurface = const Color(0xffffffff);
      onSurfaceVariant = const Color(0xffe2e8f0);
      outlineVariant = const Color(0xff64748b);
      secondaryContainer = const Color(0xff1e293b);
      surfaceContainerHighest = const Color(0xff0f172a);
    } else {
      canvas = const Color(0xffffffff);
      surface = const Color(0xffffffff);
      primary = const Color(0xff0f172a);
      onSurface = const Color(0xff000000);
      onSurfaceVariant = const Color(0xff1e293b);
      outlineVariant = const Color(0xff334155);
      secondaryContainer = const Color(0xfff1f5f9);
      surfaceContainerHighest = const Color(0xffe2e8f0);
    }
  } else {
    switch (contrastTheme) {
      case AppContrastTheme.cryptoGreen:
        canvas = dark ? const Color(0xff06130d) : const Color(0xfff0fdf4);
        surface = dark ? const Color(0xff0d1f17) : Colors.white;
        primary = dark ? const Color(0xff34d399) : const Color(0xff059669);
        onSurface = dark ? const Color(0xffecfdf5) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffa7f3d0)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff153225)
            : const Color(0xffd1fae5);
        secondaryContainer = dark
            ? const Color(0xff102e21)
            : const Color(0xffdcfce7);
        surfaceContainerHighest = dark
            ? const Color(0xff13281e)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.bitcoinGold:
        canvas = dark ? const Color(0xff0c0a06) : const Color(0xfffffbeb);
        surface = dark ? const Color(0xff17140e) : Colors.white;
        primary = dark ? const Color(0xfffbbf24) : const Color(0xffd97706);
        onSurface = dark ? const Color(0xfffef3c7) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xfffde68a)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff292318)
            : const Color(0xfffde68a);
        secondaryContainer = dark
            ? const Color(0xff261e10)
            : const Color(0xfffef3c7);
        surfaceContainerHighest = dark
            ? const Color(0xff211a0e)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.ethereumBlue:
        canvas = dark ? const Color(0xff080e18) : const Color(0xfff0f9ff);
        surface = dark ? const Color(0xff0f192b) : Colors.white;
        primary = dark ? const Color(0xff38bdf8) : const Color(0xff0284c7);
        onSurface = dark ? const Color(0xffe0f2fe) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffbae6fd)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff17283c)
            : const Color(0xffbae6fd);
        secondaryContainer = dark
            ? const Color(0xff12233c)
            : const Color(0xffe0f2fe);
        surfaceContainerHighest = dark
            ? const Color(0xff142135)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.neonViolet:
        canvas = dark ? const Color(0xff0e0a19) : const Color(0xfffaf5ff);
        surface = dark ? const Color(0xff171226) : Colors.white;
        primary = dark ? const Color(0xffa78bfa) : const Color(0xff7c3aed);
        onSurface = dark ? const Color(0xfff3e8ff) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffddd6fe)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff2a1e47)
            : const Color(0xffddd6fe);
        secondaryContainer = dark
            ? const Color(0xff241740)
            : const Color(0xfff3e8ff);
        surfaceContainerHighest = dark
            ? const Color(0xff1e1436)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.standard:
      case AppContrastTheme.highContrast:
        canvas = dark ? const Color(0xff0b0f19) : const Color(0xfff8fafc);
        surface = dark ? const Color(0xff131b2e) : Colors.white;
        primary = dark ? const Color(0xff818cf8) : const Color(0xff4f46e5);
        onSurface = dark ? const Color(0xfff8fafc) : const Color(0xff0f172a);
        onSurfaceVariant = dark
            ? const Color(0xff94a3b8)
            : const Color(0xff64748b);
        outlineVariant = dark
            ? const Color(0xff1e293b)
            : const Color(0xffe2e8f0);
        secondaryContainer = dark
            ? const Color(0xff1e1b4b)
            : const Color(0xffeef2ff);
        surfaceContainerHighest = dark
            ? const Color(0xff1e293b)
            : const Color(0xfff1f5f9);
        break;
    }
  }

  final scheme = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: contrastTheme.seedColor,
    primary: primary,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outlineVariant: outlineVariant,
    secondaryContainer: secondaryContainer,
    surfaceContainerHighest: surfaceContainerHighest,
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WalletRadius.small),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      color: scheme.onSurface,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
      color: scheme.onSurface,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
      color: scheme.onSurface,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WalletRadius.medium),
        side: BorderSide(
          color: isHighContrast
              ? scheme.outlineVariant
              : scheme.outlineVariant.withValues(alpha: 0.65),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WalletRadius.large),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WalletRadius.large),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
      ),
      iconColor: scheme.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(
        color: isHighContrast
            ? scheme.outlineVariant
            : scheme.outlineVariant.withValues(alpha: 0.7),
        width: isHighContrast ? 1.5 : 1.0,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: isHighContrast ? 1.0 : 0.6),
      space: 1,
      thickness: isHighContrast ? 1.5 : 1.0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
        borderSide: BorderSide(
          color: scheme.primary,
          width: 1.5,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
