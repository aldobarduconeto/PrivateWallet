import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/group_purchase.dart';
import 'startup_storage.dart';

class GroupPurchaseStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.group_purchases.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<GroupPurchase>> load() async {
    final raw = await _storage.readForStartup(_key);
    if (raw == null) return [];
    final items = <GroupPurchase>[];
    for (final row in jsonDecode(raw) as List<dynamic>) {
      try {
        items.add(GroupPurchase.fromJson(row as Map<String, dynamic>));
      } on Object {
        // Ignora item corrompido
      }
    }
    return items;
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<GroupPurchase> purchases) =>
      _storage.write(key: _key, value: jsonEncode(purchases));
}
