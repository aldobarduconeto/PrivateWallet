import 'package:flutter/services.dart';

enum AppPermission {
  notification(
    'Notificações do Sistema',
    'Avisos imediatos sobre confirmações on-chain, transferências recebidas e alertas de orçamento.',
    'notification',
  ),
  storage(
    'Armazenamento e Arquivos',
    'Salvar comprovantes bancários oficiais e extratos em texto (.txt). Sem acesso à galeria de fotos.',
    'storage',
  ),
  background(
    'Execução em Segundo Plano',
    'Sincronização periódica em background de saldos e transações pendentes sem travar o aplicativo.',
    'background',
  ),
  network(
    'Rede e Dados Móveis',
    'Monitoramento inteligente de conexão (Wi-Fi e rede móvel) e sincronia com nós da blockchain.',
    'network',
  );

  /// Inicializa a configuração de app permissions.
  const AppPermission(this.title, this.description, this.key);
  final String title;
  final String description;
  final String key;
}

class AppPermissionsService {
  static const _channel = MethodChannel('com.awesome/permissions');

  // Cache em memória para plataformas desktop / fallbacks
  static final _grantedFallbacks = <AppPermission, bool>{};

  /// Verifica se a permissão foi concedida no sistema operacional.
  static Future<bool> isGranted(AppPermission permission) async {
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission', {
        'permission': permission.key,
      });
      return res ?? false;
    } catch (_) {
      // Em desktop (Windows/macOS/Linux), rede e armazenamento local são permitidos por padrão.
      if (permission == AppPermission.network ||
          permission == AppPermission.storage) {
        return true;
      }
      return _grantedFallbacks[permission] ?? false;
    }
  }

  /// Solicita a permissão no sistema operacional (abre o prompt nativo do Android/iOS).
  static Future<bool> request(AppPermission permission) async {
    try {
      await _channel.invokeMethod<bool>('requestPermission', {
        'permission': permission.key,
      });
      // Verifica novamente após o pedido
      return await isGranted(permission);
    } catch (_) {
      _grantedFallbacks[permission] = true;
      return true;
    }
  }

  /// Solicita a isenção de otimização de bateria para background sync.
  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod<void>('requestBatteryOptimization');
    } catch (_) {}
  }

  /// Abre as configurações do aplicativo no sistema operacional.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }

  /// Retorna o tipo de conexão ativa (wifi, cellular, ethernet ou offline).
  static Future<String> getNetworkType() async {
    try {
      final res = await _channel.invokeMethod<String>('getNetworkType');
      return res ?? 'other';
    } catch (_) {
      return 'wifi';
    }
  }
}
