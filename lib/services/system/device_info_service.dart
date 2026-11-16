import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoData {
  /// Inicializa [DeviceInfoData] com os dados recebidos.
  const DeviceInfoData({
    required this.name,
    required this.platform,
    this.model,
  });

  final String name;
  final String platform;
  final String? model;

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'name': name,
    'platform': platform,
    if (model != null && model!.isNotEmpty) 'model': model,
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory DeviceInfoData.fromJson(Map<String, dynamic> json) => DeviceInfoData(
    name: json['name'] as String? ?? 'Dispositivo desconhecido',
    platform: json['platform'] as String? ?? 'Desconhecido',
    model: json['model'] as String?,
  );
}

class DeviceInfoService {
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Monta os dados do dispositivo com o estado atual.
  static Future<DeviceInfoData> getDevice() async {
    try {
      if (kIsWeb) {
        final web = await _plugin.webBrowserInfo;
        return DeviceInfoData(name: web.browserName.name, platform: 'Web');
      }

      if (Platform.isAndroid) {
        final android = await _plugin.androidInfo;
        final brand = android.brand.trim();
        final model = android.model.trim();
        final name =
            (brand.isNotEmpty &&
                !model.toLowerCase().contains(brand.toLowerCase()))
            ? '$brand $model'
            : model.isNotEmpty
            ? model
            : 'Android';
        return DeviceInfoData(
          name: name,
          platform: 'Android ${android.version.release}',
          model: android.model,
        );
      }

      if (Platform.isIOS) {
        final ios = await _plugin.iosInfo;
        final name = ios.name.trim().isNotEmpty
            ? ios.name.trim()
            : (ios.model.trim().isNotEmpty ? ios.model.trim() : 'iPhone');
        return DeviceInfoData(
          name: name,
          platform: '${ios.systemName} ${ios.systemVersion}',
          model: ios.model,
        );
      }

      if (Platform.isWindows) {
        final win = await _plugin.windowsInfo;
        final computer = win.computerName.trim();
        final name = computer.isNotEmpty
            ? computer
            : (Platform.localHostname.isNotEmpty
                  ? Platform.localHostname
                  : 'PC Windows');
        return DeviceInfoData(
          name: name,
          platform: win.productName.isNotEmpty ? win.productName : 'Windows',
          model: win.displayVersion,
        );
      }

      if (Platform.isMacOS) {
        final mac = await _plugin.macOsInfo;
        final name = mac.computerName.trim().isNotEmpty
            ? mac.computerName.trim()
            : (mac.model.trim().isNotEmpty ? mac.model.trim() : 'Mac');
        return DeviceInfoData(
          name: name,
          platform: 'macOS ${mac.osRelease}',
          model: mac.model,
        );
      }

      if (Platform.isLinux) {
        final linux = await _plugin.linuxInfo;
        final name = linux.prettyName.trim().isNotEmpty
            ? linux.prettyName.trim()
            : (Platform.localHostname.isNotEmpty
                  ? Platform.localHostname
                  : 'Linux');
        return DeviceInfoData(name: name, platform: 'Linux');
      }
    } catch (_) {
      // Ignora erro e recorre ao fallback com Platform
    }

    try {
      final host = Platform.localHostname;
      final os = Platform.operatingSystem;
      return DeviceInfoData(
        name: host.isNotEmpty ? host : 'Dispositivo $os',
        platform: os,
      );
    } catch (_) {
      return const DeviceInfoData(
        name: 'Dispositivo desconhecido',
        platform: 'Desconhecido',
      );
    }
  }
}
