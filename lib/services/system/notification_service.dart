import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_permissions_service.dart';

class NotificationService {
  static const _channel = MethodChannel('com.awesome/notifications');

  /// Dispara uma notificação nativa no sistema operacional.
  static Future<void> notify({
    required String title,
    required String body,
    int id = 1001,
    BuildContext? context,
  }) async {
    final granted = await AppPermissionsService.isGranted(
      AppPermission.notification,
    );
    if (!granted) {
      // Se não tiver permissão do sistema, exibe notificação visual na UI (SnackBar elegante)
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(body, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    try {
      await _channel.invokeMethod<bool>('showNotification', {
        'title': title,
        'body': body,
        'id': id,
      });
    } catch (_) {
      // Fallback visual
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('$title: $body'),
          ),
        );
      }
    }
  }
}
