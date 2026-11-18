import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auto_debit_plan.dart';
import 'startup_storage.dart';

class AutoDebitStore {
  /// Inicializa [AutoDebitStore] com os dados recebidos.
  const AutoDebitStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'private_wallet.auto_debits.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<AutoDebitPlan>> load() async {
    final raw = await _storage.readForStartup(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AutoDebitPlan.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<AutoDebitPlan> plans) async {
    final raw = jsonEncode(plans.map((p) => p.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }
}
