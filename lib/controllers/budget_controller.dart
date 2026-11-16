import 'package:flutter/foundation.dart';

import '../models/spending_budget.dart';
import '../services/storage/budget_store.dart';

class BudgetController extends ValueNotifier<Map<String, SpendingBudget>> {
  /// Inicializa [BudgetController] com os dados recebidos.
  BudgetController() : super(const {});

  final _store = BudgetStore();
  bool _disposed = false;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final map = await _store.load();
    if (!_disposed) value = map;
  }

  /// Retorna o orçamento.
  SpendingBudget getBudget(String symbol) =>
      value[symbol.toUpperCase()] ??
      SpendingBudget(
        symbol: symbol.toUpperCase(),
        monthlyLimit: 0.0,
        updatedAt: DateTime.now(),
      );

  /// Define o limite mensal.
  Future<void> setMonthlyLimit(String symbol, double limit) async {
    final sym = symbol.toUpperCase();
    final updated = Map<String, SpendingBudget>.from(value);
    updated[sym] = SpendingBudget(
      symbol: sym,
      monthlyLimit: limit,
      updatedAt: DateTime.now(),
    );
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
