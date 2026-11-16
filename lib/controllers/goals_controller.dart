import 'package:flutter/foundation.dart';

import '../models/financial_goal.dart';
import '../services/storage/goals_store.dart';

class GoalsController extends ValueNotifier<List<FinancialGoal>> {
  /// Inicializa [GoalsController] com os dados recebidos.
  GoalsController({GoalsStore? store})
    : _store = store ?? GoalsStore(),
      super(const []);

  final GoalsStore _store;
  bool _loaded = false;

  /// Retorna `loaded` para consulta em metas.
  bool get loaded => _loaded;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final list = await _store.load();
    value = List.unmodifiable(list);
    _loaded = true;
  }

  /// Filtra os registros pelo símbolo do ativo.
  List<FinancialGoal> forSymbol(String symbol) => value
      .where((g) => g.symbol.toUpperCase() == symbol.toUpperCase())
      .toList();

  /// Filtra as metas pelo ativo informado.
  List<FinancialGoal> goalsForSymbol(String symbol) => forSymbol(symbol);

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> add(FinancialGoal goal) async {
    final updated = [...value, goal];
    await _store.save(updated);
    value = List.unmodifiable(updated);
  }

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> remove(String id) async {
    final updated = value.where((g) => g.id != id).toList();
    await _store.save(updated);
    value = List.unmodifiable(updated);
  }
}
