import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/wallet_account.dart';
import '../gas_tracker_service.dart';
import 'clipboard_guard_service.dart';

/// Serviço que orquestra as ações e status integrados à barra de título / cabeçalho desktop.
class HeaderCommandService {
  HeaderCommandService._();

  static final HeaderCommandService instance = HeaderCommandService._();

  // Callbacks fornecidos pelo painel da carteira (WalletHome)
  VoidCallback? onOpenSend;
  VoidCallback? onOpenReceive;
  VoidCallback? onOpenStatement;
  VoidCallback? onOpenFinance;
  VoidCallback? onOpenPos;
  VoidCallback? onOpenGasTracker;
  VoidCallback? onOpenPrivacyStealth;
  VoidCallback? onOpenAddressInspector;
  VoidCallback? onOpenMarket;
  VoidCallback? onOpenContacts;
  VoidCallback? onOpenAutoDebits;
  VoidCallback? onOpenSettings;
  VoidCallback? onToggleHideBalance;
  bool Function()? isBalanceHidden;
  WalletAccount? Function()? getActiveAccount;

  // Notificadores de estado para atualização reativa do cabeçalho
  final ValueNotifier<GasFeeInfo?> gasInfoNotifier = ValueNotifier<GasFeeInfo?>(null);
  final ValueNotifier<bool> hideBalanceNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> networkLabelNotifier = ValueNotifier<String>('Sepolia');

  Timer? _gasPollTimer;

  /// Inicia o monitoramento de gas em segundo plano para o cabeçalho.
  void startGasMonitoring() {
    _gasPollTimer?.cancel();
    refreshGas();
    _gasPollTimer = Timer.periodic(const Duration(minutes: 2), (_) => refreshGas());
  }

  /// Cancela o monitoramento ao desativar.
  void stopGasMonitoring() {
    _gasPollTimer?.cancel();
    _gasPollTimer = null;
  }

  /// Atualiza a estimativa de gas sob demanda.
  Future<void> refreshGas() async {
    try {
      const service = GasTrackerService();
      final info = await service.fetchCurrentGas();
      gasInfoNotifier.value = info;
    } on Object catch (_) {}
  }

  /// Alterna a visibilidade dos saldos através do cabeçalho.
  void toggleBalancePrivacy() {
    if (onToggleHideBalance != null) {
      onToggleHideBalance!();
    }
    hideBalanceNotifier.value = !hideBalanceNotifier.value;
  }

  /// Purga os dados confidenciais da área de transferência imediatamente.
  Future<void> cleanClipboard(BuildContext context) async {
    await ClipboardGuardService.clearNow();
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Text('Área de transferência limpa imediatamente por segurança.'),
            ],
          ),
        ),
      );
    }
  }
}
