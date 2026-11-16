import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../models/app_contrast_theme.dart';

const walletInk = Color(0xff17213a);
const walletHeroMuted = Color(0xffd1dcf5);

/// Raios padronizados do design system.
abstract final class WalletRadius {
  static const small = 12.0;
  static const medium = 16.0;
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
        canvas = dark ? const Color(0xff091410) : const Color(0xfff0fdf4);
        surface = dark ? const Color(0xff10201a) : Colors.white;
        primary = dark ? const Color(0xff6ee7b7) : const Color(0xff059669);
        onSurface = dark ? const Color(0xffecfdf5) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffa7f3d0)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff1d3f34)
            : const Color(0xffcbd5e1);
        secondaryContainer = dark
            ? const Color(0xff133026)
            : const Color(0xffdcfce7);
        surfaceContainerHighest = dark
            ? const Color(0xff172d24)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.bitcoinGold:
        canvas = dark ? const Color(0xff141008) : const Color(0xfffffbeb);
        surface = dark ? const Color(0xff221b0e) : Colors.white;
        primary = dark ? const Color(0xfffcd34d) : const Color(0xffd97706);
        onSurface = dark ? const Color(0xfffef3c7) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xfffde68a)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff443419)
            : const Color(0xffcbd5e1);
        secondaryContainer = dark
            ? const Color(0xff332712)
            : const Color(0xfffef3c7);
        surfaceContainerHighest = dark
            ? const Color(0xff2c2211)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.ethereumBlue:
        canvas = dark ? const Color(0xff09131a) : const Color(0xfff0f9ff);
        surface = dark ? const Color(0xff101f2b) : Colors.white;
        primary = dark ? const Color(0xff7dd3fc) : const Color(0xff0284c7);
        onSurface = dark ? const Color(0xffe0f2fe) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffbae6fd)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff1d3d54)
            : const Color(0xffcbd5e1);
        secondaryContainer = dark
            ? const Color(0xff152d3f)
            : const Color(0xffe0f2fe);
        surfaceContainerHighest = dark
            ? const Color(0xff162939)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.neonViolet:
        canvas = dark ? const Color(0xff110c1c) : const Color(0xfffaf5ff);
        surface = dark ? const Color(0xff1b142c) : Colors.white;
        primary = dark ? const Color(0xffc4b5fd) : const Color(0xff7c3aed);
        onSurface = dark ? const Color(0xfff3e8ff) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffddd6fe)
            : const Color(0xff374151);
        outlineVariant = dark
            ? const Color(0xff382759)
            : const Color(0xffcbd5e1);
        secondaryContainer = dark
            ? const Color(0xff2b1c45)
            : const Color(0xfff3e8ff);
        surfaceContainerHighest = dark
            ? const Color(0xff241a3a)
            : const Color(0xfff1f5f9);
        break;
      case AppContrastTheme.standard:
      case AppContrastTheme.highContrast:
        canvas = dark ? const Color(0xff101521) : const Color(0xfff4f6fb);
        surface = dark ? const Color(0xff1b2333) : Colors.white;
        primary = dark ? const Color(0xffc5bdff) : const Color(0xff5144c9);
        onSurface = dark ? const Color(0xffecf0fa) : walletInk;
        onSurfaceVariant = dark
            ? const Color(0xffb8c3d8)
            : const Color(0xff53617a);
        outlineVariant = dark
            ? const Color(0xff35425b)
            : const Color(0xffdce3ed);
        secondaryContainer = dark
            ? const Color(0xff353056)
            : const Color(0xffeeecff);
        surfaceContainerHighest = dark
            ? const Color(0xff253047)
            : const Color(0xffeef1f8);
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
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
      color: scheme.onSurface,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
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
          color: scheme.outlineVariant,
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
    listTileTheme: ListTileThemeData(shape: rounded, iconColor: scheme.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(
        color: scheme.outlineVariant,
        width: isHighContrast ? 1.5 : 1.0,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: isHighContrast ? 1.5 : 1.0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: canvas,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WalletRadius.small),
        borderSide: BorderSide(
          color: scheme.outlineVariant,
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded,
        side: BorderSide(
          color: scheme.outlineVariant,
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: rounded),
    ),
  );
}
