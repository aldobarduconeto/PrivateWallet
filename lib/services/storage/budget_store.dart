import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/spending_budget.dart';

class BudgetStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.budget.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<Map<String, SpendingBudget>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(
          k.toString(),
          SpendingBudget.fromJson(v as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(Map<String, SpendingBudget> budgets) async {
    final raw = jsonEncode(budgets.map((k, v) => MapEntry(k, v.toJson())));
    await _storage.write(key: _key, value: raw);
  }
}
