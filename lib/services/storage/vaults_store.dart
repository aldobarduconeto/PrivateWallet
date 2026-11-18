import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/crypto_vault.dart';
import 'startup_storage.dart';

class VaultsStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.vaults.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<CryptoVault>> load() async {
    final raw = await _storage.readForStartup(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CryptoVault.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<CryptoVault> vaults) async {
    final raw = jsonEncode(vaults.map((v) => v.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }
}
