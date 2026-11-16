import 'package:flutter/foundation.dart';

import '../models/group_purchase.dart';
import '../services/storage/group_purchase_store.dart';

/// Gerenciador de Compras Conjuntas (Racha Coletivo Soberano).
class GroupPurchaseController extends ValueNotifier<List<GroupPurchase>> {
  /// Inicializa [GroupPurchaseController] com os dados recebidos.
  GroupPurchaseController({GroupPurchaseStore? store})
    : _store = store ?? GroupPurchaseStore(),
      super(const []);

  final GroupPurchaseStore _store;
  bool _loaded = false;

  /// Retorna `loaded` para consulta em compras conjuntas.
  bool get loaded => _loaded;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final list = await _store.load();
    // Ordena pelas mais recentes
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    value = List.unmodifiable(list);
    _loaded = true;
  }

  /// Cria uma compra conjunta e salva seus dados iniciais.
  Future<void> create(GroupPurchase purchase) async {
    final updated = [purchase, ...value];
    await _save(updated);
  }

  /// Exclui a compra conjunta selecionada.
  Future<void> delete(String id) async {
    final updated = value.where((p) => p.id != id).toList();
    await _save(updated);
  }

  /// Alterna `member paid` no fluxo de compras conjuntas.
  Future<void> toggleMemberPaid(
    String purchaseId,
    String memberId, {
    String? txHash,
  }) async {
    final updated = value.map((purchase) {
      if (purchase.id != purchaseId) return purchase;

      final updatedMembers = purchase.members.map((member) {
        if (member.id != memberId) return member;

        final nextPaid = !member.isPaid;
        return member.copyWith(
          isPaid: nextPaid,
          paidAt: nextPaid ? (member.paidAt ?? DateTime.now()) : null,
          txHash: nextPaid ? (txHash ?? member.txHash) : null,
        );
      }).toList();

      return purchase.copyWith(members: updatedMembers);
    }).toList();

    await _save(updated);
  }

  /// Adiciona o participante.
  Future<void> addMember(String purchaseId, GroupPurchaseMember member) async {
    final updated = value.map((purchase) {
      if (purchase.id != purchaseId) return purchase;
      if (purchase.members.any((m) => m.id == member.id)) return purchase;

      final newMembers = [...purchase.members, member];
      // Recalcula o split igualitário se aplicável
      final equalShare = purchase.totalAmount / newMembers.length;
      final rebalanced = newMembers
          .map((m) => m.copyWith(shareAmount: equalShare))
          .toList();

      return purchase.copyWith(members: rebalanced);
    }).toList();

    await _save(updated);
  }

  /// Remove o participante.
  Future<void> removeMember(String purchaseId, String memberId) async {
    final updated = value.map((purchase) {
      if (purchase.id != purchaseId) return purchase;

      final newMembers = purchase.members
          .where((m) => m.id != memberId)
          .toList();
      if (newMembers.isEmpty) return purchase;

      final equalShare = purchase.totalAmount / newMembers.length;
      final rebalanced = newMembers
          .map((m) => m.copyWith(shareAmount: equalShare))
          .toList();

      return purchase.copyWith(members: rebalanced);
    }).toList();

    await _save(updated);
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> _save(List<GroupPurchase> purchases) async {
    purchases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _store.save(purchases);
    value = List.unmodifiable(purchases);
  }
}
