import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../controllers/auto_debit_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../models/auto_debit_plan.dart';
import '../crypto_market_service.dart';
import 'app_permissions_service.dart';
import 'notification_service.dart';

class BackgroundSyncService {
  /// Inicializa [BackgroundSyncService] com os dados recebidos.
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;
  final _debitReminders = <String, DateTime>{};

  /// Avisa uma vez por vencimento durante a sessão, sem expor dados do plano.
  Future<void> _remindDebit(AutoDebitPlan plan, {required bool pending}) async {
    if (_debitReminders[plan.id] == plan.nextExecution) return;
    await NotificationService.notify(
      id: 2000 + (plan.id.hashCode & 0xffff),
      title: pending ? 'Pagamento pendente' : 'Débito automático próximo',
      body: pending
          ? 'Abra o PrivateWallet para revisar um pagamento que exige confirmação.'
          : 'Há um envio automático previsto nas próximas 24 horas. Você pode revisar o plano no PrivateWallet.',
    );
    _debitReminders[plan.id] = plan.nextExecution;
  }

  /// Retorna se o temporizador periódico de background está ativo.
  bool get isActive => _syncTimer != null && _syncTimer!.isActive;

  /// Inicia a rotina de sincronização periódica em background.
  void start({
    required WalletController controller,
    AutoDebitController? autoDebitController,
    VoidCallback? onBalanceUpdated,
    Duration interval = const Duration(minutes: 5),
  }) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) async {
      await performSync(
        controller: controller,
        autoDebitController: autoDebitController,
        onBalanceUpdated: onBalanceUpdated,
      );
    });
  }

  /// Executa um ciclo de sincronização de saldo silencioso e débitos automáticos em background.
  Future<void> performSync({
    required WalletController controller,
    AutoDebitController? autoDebitController,
    VoidCallback? onBalanceUpdated,
  }) async {
    if (_isSyncing || controller.accounts.isEmpty) return;
    _isSyncing = true;

    try {
      if (autoDebitController != null) {
        final plans = autoDebitController.activePlans();
        final activeIds = plans.map((plan) => plan.id).toSet();
        _debitReminders.removeWhere((id, _) => !activeIds.contains(id));
        final now = DateTime.now();
        final tomorrow = now.add(const Duration(hours: 24));
        for (final plan in plans) {
          if (plan.autoExecution &&
              plan.nextExecution.isAfter(now) &&
              !plan.nextExecution.isAfter(tomorrow)) {
            await _remindDebit(plan, pending: false);
          }
        }
      }
      final netType = await AppPermissionsService.getNetworkType();
      if (netType == 'offline' || controller.accounts.isEmpty) return;

      final account = controller.account;
      final network = controller.network;
      final prevBalance = controller.lastKnownBalance();
      final newBalance = await controller
          .balance(force: true)
          .then<BigInt?>((balance) => balance, onError: (Object _) => null);

      // Notificação de novos depósitos
      if (prevBalance != null &&
          newBalance != null &&
          newBalance > prevBalance) {
        final symbol = account.symbol;
        await NotificationService.notify(
          title: 'Novo depósito recebido! 💰',
          body: 'Sua carteira ${account.name} recebeu novos fundos em $symbol.',
        );
        onBalanceUpdated?.call();
      }

      // Processamento de Débitos Automáticos (Assinaturas e Aluguéis)
      if (autoDebitController != null) {
        final duePlans = autoDebitController.duePlans(account.publicAddress);
        for (final plan in duePlans) {
          if (controller.accounts.isEmpty ||
              !identical(controller.account, account) ||
              controller.network != network) {
            break;
          }
          if (!autoDebitController.value.contains(plan)) continue;
          if (plan.autoExecution && account.canSign) {
            try {
              await autoDebitController.executePlan(
                plan: plan,
                walletController: controller,
                account: account,
              );
              onBalanceUpdated?.call();
            } catch (_) {
              // Falha silenciosa em background (ex: taxa insuficiente)
            }
          } else {
            await _remindDebit(plan, pending: true);
          }
        }
      }

      // Verificação periódica de alertas de preço cripto
      try {
        const marketService = CryptoMarketService();
        final assets = await marketService.fetchAssets();
        await marketService.checkAndTriggerAlerts(assets);
      } catch (_) {}
    } catch (_) {
      // Falha silenciosa em background para não interromper a UX do usuário
    } finally {
      _isSyncing = false;
    }
  }

  /// Cancela o temporizador de sincronização em segundo plano.
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
