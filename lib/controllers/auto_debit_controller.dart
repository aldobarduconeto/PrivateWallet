import 'package:flutter/foundation.dart';

import '../blockchain/coin_formatter.dart';
import '../models/auto_debit_plan.dart';
import '../models/wallet_account.dart';
import '../services/payment_service.dart';
import '../services/storage/auto_debit_store.dart';
import '../services/system/notification_service.dart';
import 'wallet_controller.dart';

class AutoDebitController extends ValueNotifier<List<AutoDebitPlan>> {
  /// Inicializa [AutoDebitController] com os dados recebidos.
  AutoDebitController([AutoDebitStore? store])
    : _store = store ?? const AutoDebitStore(),
      super(const []);

  final AutoDebitStore _store;
  bool _disposed = false;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final list = await _store.load();
    if (!_disposed) value = list;
  }

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> add(AutoDebitPlan plan) async {
    final updated = [...value, plan];
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Cancela o débito automático imediatamente a qualquer momento.
  Future<void> cancel(String id) async {
    final updated = value.map((plan) {
      if (plan.id == id) {
        return plan.cancel();
      }
      return plan;
    }).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Reativa um débito automático previamente cancelado ou pausado.
  Future<void> resume(String id) async {
    final updated = value.map((plan) {
      if (plan.id == id) {
        return plan.resume();
      }
      return plan;
    }).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Alterna entre ativo e cancelado/pausado.
  Future<void> toggle(String id) async {
    final plan = value.firstWhere((p) => p.id == id);
    if (plan.isActive) {
      await cancel(id);
    } else {
      await resume(id);
    }
  }

  /// Exclui o plano de débito permanentemente.
  Future<void> remove(String id) async {
    final updated = value.where((p) => p.id != id).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Retorna apenas os planos ativos da carteira informada (ou de todas se null).
  List<AutoDebitPlan> activePlans([String? walletAddress]) {
    return value.where((p) {
      final matchesWallet =
          walletAddress == null ||
          p.walletAddress == null ||
          p.walletAddress == walletAddress;
      return p.isActive && matchesWallet;
    }).toList();
  }

  /// Retorna os planos vencidos e pendentes de execução.
  List<AutoDebitPlan> duePlans([String? walletAddress]) {
    return value.where((p) {
      final matchesWallet =
          walletAddress == null ||
          p.walletAddress == null ||
          p.walletAddress == walletAddress;
      return p.isDue && matchesWallet;
    }).toList();
  }

  /// Registra uma execução no histórico do plano e calcula a próxima data.
  Future<void> recordExecution(
    String planId,
    AutoDebitExecution execution,
  ) async {
    final updated = value.map((plan) {
      if (plan.id == planId) {
        return plan.recordExecution(execution);
      }
      return plan;
    }).toList();
    await _store.save(updated);
    if (!_disposed) value = updated;
  }

  /// Executa o débito on-chain usando o WalletController autenticado.
  Future<String?> executePlan({
    required AutoDebitPlan plan,
    required WalletController walletController,
    required WalletAccount account,
  }) async {
    if (!account.canSign) {
      throw const FormatException(
        'Carteira em modo leitura não pode assinar débitos automáticos.',
      );
    }

    final Payment payment = (to: plan.recipientAddress, amount: plan.amount);

    final prepared = await walletController.prepare(
      payment,
      paymentType: plan.category.label,
      purchaseName: plan.title,
    );

    try {
      final result = await prepared.send();
      final hash = result.hash;

      final execution = AutoDebitExecution(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        txHash: hash,
        amount: plan.amount,
        symbol: plan.symbol,
        success: true,
      );

      await recordExecution(plan.id, execution);

      final formattedAmount = CoinFormatter.format(plan.amount, plan.symbol);
      await NotificationService.notify(
        title: 'Débito Automático Pago! 💳',
        body:
            '${plan.title} ($formattedAmount ${plan.symbol}) foi enviado com sucesso.',
      );

      return hash;
    } catch (e) {
      final execution = AutoDebitExecution(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        txHash: '',
        amount: plan.amount,
        symbol: plan.symbol,
        success: false,
        errorMessage: e.toString(),
      );
      await recordExecution(plan.id, execution);
      rethrow;
    } finally {
      await prepared.close();
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
