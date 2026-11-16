import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/wallet_activity.dart';

class ActivityStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.activity.v1';

  /// Limite de envios guardados. Mantém a leitura do armazenamento seguro
  /// rápida mesmo após muito uso; os mais antigos seguem no explorador.
  static const maxEntries = 300;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<WalletActivity>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => WalletActivity.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Registra o evento para consulta posterior.
  Future<void> record(WalletActivity activity) async {
    final previous = await load();
    previous.removeWhere(
      (item) =>
          item.hash == activity.hash &&
          item.networkId == activity.networkId &&
          item.bitcoin == activity.bitcoin,
    );
    final entries = [activity, ...previous].take(maxEntries).toList();
    await _storage.write(key: _key, value: jsonEncode(entries));
  }
}
