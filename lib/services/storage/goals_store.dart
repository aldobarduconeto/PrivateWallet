import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/financial_goal.dart';

class GoalsStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.goals.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<FinancialGoal>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final list = <FinancialGoal>[];
    for (final item in jsonDecode(raw) as List<dynamic>) {
      try {
        list.add(FinancialGoal.fromJson(item as Map<String, dynamic>));
      } catch (_) {
        // Ignora meta corrompida
      }
    }
    return list;
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<FinancialGoal> goals) async {
    await _storage.write(key: _key, value: jsonEncode(goals));
  }
}
