import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/wallet_account.dart';
import 'startup_storage.dart';

class WalletStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.accounts.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<WalletAccount>> load() async {
    final raw = await _storage.readForStartup(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((row) => WalletAccount.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<WalletAccount> accounts) =>
      _storage.write(key: _key, value: jsonEncode(accounts));
}
