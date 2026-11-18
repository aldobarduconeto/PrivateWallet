import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/app_language.dart';
import '../../models/app_contrast_theme.dart';
import '../../models/fiat_currency.dart';
import '../../models/networks.dart';
import '../../models/wallet_preferences.dart';
import 'startup_storage.dart';

class WalletPreferencesStore {
  /// Inicializa [WalletPreferencesStore] com os dados recebidos.
  const WalletPreferencesStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'private_wallet.preferences.v1';
  static const _legacyTheme = 'private_wallet.theme';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<WalletPreferences> load() async {
    final stored = await _storage.readForStartup(_key);
    if (stored == null) {
      final theme = await _storage.readForStartup(_legacyTheme);
      return WalletPreferences(theme: _themeFrom(theme));
    }
    final json = jsonDecode(stored);
    if (json is! Map<String, dynamic>) return const WalletPreferences();
    return WalletPreferences(
      theme: _themeFrom(json['theme']),
      contrastTheme: _contrastFrom(json['contrastTheme']),
      language: AppLanguage.fromCode(json['language'] as String?),
      fiatCurrency: switch (json['fiatCurrency']) {
        final String code when RegExp(r'^[A-Z]{3}$').hasMatch(code) =>
          FiatCurrency(code),
        _ => FiatCurrency.brl,
      },
      ethereumNetwork: json['ethereumNetwork'] == Network.mainnet.name
          ? Network.mainnet
          : Network.sepolia,
      hideBalanceAtStartup: json['hideBalanceAtStartup'] == true,
      hideBalanceInBackground: json['hideBalanceInBackground'] == true,
      biometricAuthEnabled: json['biometricAuthEnabled'] == true,
      desktopPasswordEnabled: json['desktopPasswordEnabled'] == true,
      lockOnBackground: json['lockOnBackground'] == true,
    );
  }

  /// Converte o valor persistido para um tema reconhecido.
  ThemeMode _themeFrom(Object? value) => ThemeMode.values.firstWhere(
    (theme) => theme.name == value,
    orElse: () => ThemeMode.system,
  );

  /// Converte o valor persistido para um contraste reconhecido.
  AppContrastTheme _contrastFrom(Object? value) =>
      AppContrastTheme.values.firstWhere(
        (theme) => theme.name == value,
        orElse: () => AppContrastTheme.standard,
      );

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(WalletPreferences values) => _storage.write(
    key: _key,
    value: jsonEncode({
      'theme': values.theme.name,
      'contrastTheme': values.contrastTheme.name,
      'language': values.language.code,
      'fiatCurrency': values.fiatCurrency.code,
      'ethereumNetwork': values.ethereumNetwork.name,
      'hideBalanceAtStartup': values.hideBalanceAtStartup,
      'hideBalanceInBackground': values.hideBalanceInBackground,
      'biometricAuthEnabled': values.biometricAuthEnabled,
      'desktopPasswordEnabled': values.desktopPasswordEnabled,
      'lockOnBackground': values.lockOnBackground,
    }),
  );
}
