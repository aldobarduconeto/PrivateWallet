import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Serviço de segurança para a área de transferência.
/// Impede que malwares ou outros aplicativos espiões leiam chaves privadas,
/// frases mnemônicas ou endereços mantidos na memória por tempo indeterminado.
class ClipboardGuardService {
  const ClipboardGuardService._();

  static Timer? _clearTimer;
  static String? _lastCopiedSensitive;
  static int _remainingSeconds = 0;
  static Timer? _countdownTimer;

  /// Retorna quantos segundos faltam para a limpeza automática.
  static int get remainingSeconds => _remainingSeconds;

  /// Indica se há uma limpeza de área de transferência agendada.
  static bool get hasPendingClear => _clearTimer != null;

  /// Copia um dado sensível (chave privada, seed, hash ou endereço) e agenda
  /// a limpeza automática da área de transferência após [timeoutSeconds] (padrão: 45 segundos).
  static Future<void> copySensitive({
    required BuildContext context,
    required String text,
    String label = 'Dado confidencial',
    int timeoutSeconds = 45,
  }) async {
    cancelPendingClear();
    _lastCopiedSensitive = text;
    _remainingSeconds = timeoutSeconds;

    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label copiado. Por segurança soberana, a área de transferência será limpa em ${timeoutSeconds}s.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Limpar Agora',
            textColor: Colors.amberAccent,
            onPressed: () => clearNow(context),
          ),
        ),
      );
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      } else {
        timer.cancel();
      }
    });

    _clearTimer = Timer(Duration(seconds: timeoutSeconds), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == _lastCopiedSensitive) {
        await Clipboard.setData(const ClipboardData(text: ''));
        _lastCopiedSensitive = null;
      }
      cancelPendingClear();
    });
  }

  /// Cancela o temporizador sem apagar o conteúdo imediatamente.
  static void cancelPendingClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remainingSeconds = 0;
  }

  /// Limpa imediatamente a área de transferência do sistema operacional.
  static Future<void> clearNow([BuildContext? context]) async {
    cancelPendingClear();
    await Clipboard.setData(const ClipboardData(text: ''));
    _lastCopiedSensitive = null;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Área de transferência limpa com sucesso.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
