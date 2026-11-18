import 'package:flutter/foundation.dart';

import '../models/wallet_preferences.dart';
import '../services/storage/preferences_store.dart';

class PreferencesController extends ValueNotifier<WalletPreferences> {
  /// Inicializa [PreferencesController] com os dados recebidos.
  PreferencesController() : super(const WalletPreferences());

  final _store = WalletPreferencesStore();
  bool _disposed = false;
  bool _saving = false;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final preferences = await _store.load();
    if (!_disposed) value = preferences;
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(WalletPreferences preferences) async {
    if (_saving) {
      throw const FormatException('Aguarde o salvamento em andamento.');
    }
    _saving = true;
    try {
      await _store.save(preferences);
      if (!_disposed) value = preferences;
    } finally {
      _saving = false;
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
