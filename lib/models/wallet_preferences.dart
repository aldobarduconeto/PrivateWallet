import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'app_contrast_theme.dart';
import 'fiat_currency.dart';
import 'networks.dart';

class WalletPreferences {
  /// Inicializa [WalletPreferences] com os dados recebidos.
  const WalletPreferences({
    this.theme = ThemeMode.system,
    this.contrastTheme = AppContrastTheme.standard,
    this.language = AppLanguage.system,
    this.ethereumNetwork = Network.sepolia,
    this.fiatCurrency = FiatCurrency.brl,
    this.hideBalanceAtStartup = false,
    this.hideBalanceInBackground = false,
    this.biometricAuthEnabled = false,
    this.desktopPasswordEnabled = false,
    this.lockOnBackground = false,
  });

  final ThemeMode theme;
  final AppContrastTheme contrastTheme;
  final AppLanguage language;
  final Network ethereumNetwork;
  final FiatCurrency fiatCurrency;
  final bool hideBalanceAtStartup;
  final bool hideBalanceInBackground;
  final bool biometricAuthEnabled;
  final bool desktopPasswordEnabled;
  final bool lockOnBackground;

  /// Cria uma cópia com os campos informados e preserva os demais.
  WalletPreferences copyWith({
    ThemeMode? theme,
    AppContrastTheme? contrastTheme,
    AppLanguage? language,
    Network? ethereumNetwork,
    FiatCurrency? fiatCurrency,
    bool? hideBalanceAtStartup,
    bool? hideBalanceInBackground,
    bool? biometricAuthEnabled,
    bool? desktopPasswordEnabled,
    bool? lockOnBackground,
  }) => WalletPreferences(
    theme: theme ?? this.theme,
    contrastTheme: contrastTheme ?? this.contrastTheme,
    language: language ?? this.language,
    ethereumNetwork: ethereumNetwork ?? this.ethereumNetwork,
    fiatCurrency: fiatCurrency ?? this.fiatCurrency,
    hideBalanceAtStartup: hideBalanceAtStartup ?? this.hideBalanceAtStartup,
    hideBalanceInBackground:
        hideBalanceInBackground ?? this.hideBalanceInBackground,
    biometricAuthEnabled: biometricAuthEnabled ?? this.biometricAuthEnabled,
    desktopPasswordEnabled:
        desktopPasswordEnabled ?? this.desktopPasswordEnabled,
    lockOnBackground: lockOnBackground ?? this.lockOnBackground,
  );
}
