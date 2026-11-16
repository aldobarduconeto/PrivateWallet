import 'package:flutter/foundation.dart';

import '../models/crypto_vault.dart';
import '../services/storage/vaults_store.dart';

class VaultsController extends ValueNotifier<List<CryptoVault>> {
  /// Inicializa [VaultsController] com os dados recebidos.
  VaultsController() : super(const []);

  final _store = VaultsStore();
  bool _disposed = false;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final list = await _store.load();
    if (!_disposed) value = list;
  }

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> add(CryptoVault vault) async {
    final updated = [...value, vault];
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> remove(String id) async {
    final updated = value.where((v) => v.id != id).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Adiciona o valor informado à reserva virtual do cofre.
  Future<void> deposit(String id, double amount) async {
    if (amount <= 0) return;
    final updated = value.map((v) {
      if (v.id == id) {
        return v.copyWith(allocatedAmount: v.allocatedAmount + amount);
      }
      return v;
    }).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Retira o valor informado da reserva virtual do cofre.
  Future<void> withdraw(String id, double amount) async {
    if (amount <= 0) return;
    final updated = value.map((v) {
      if (v.id == id) {
        final newAllocated = (v.allocatedAmount - amount).clamp(
          0.0,
          double.infinity,
        );
        return v.copyWith(allocatedAmount: newAllocated);
      }
      return v;
    }).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Soma as reservas dos cofres do ativo informado.
  double totalAllocated(String symbol) => value
      .where((v) => v.symbol.toUpperCase() == symbol.toUpperCase())
      .fold(0.0, (acc, v) => acc + v.allocatedAmount);

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
