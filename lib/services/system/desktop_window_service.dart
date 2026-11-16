import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Serviço responsável por integrar nativamente a janela de desktop (Windows, Linux, macOS)
/// com o design system do Private Wallet e fornecer controles de janela sem moldura nativa.
class DesktopWindowService {
  /// Inicializa [DesktopWindowService] com os dados recebidos.
  const DesktopWindowService._();

  static const _channel = MethodChannel('private_wallet/window');

  /// Indica se a execução atual ocorre em Windows Desktop.
  static bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

  /// Indica se a execução atual ocorre em ambiente desktop (Windows, Linux ou macOS).
  static bool get isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Minimiza a janela desktop.
  static Future<void> minimize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('minimize');
    } on Object catch (_) {}
  }

  /// Maximiza a janela desktop.
  static Future<void> maximize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('maximize');
    } on Object catch (_) {}
  }

  /// Restaura a janela desktop ao tamanho padrão.
  static Future<void> restore() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('restore');
    } on Object catch (_) {}
  }

  /// Alterna entre maximizado e restaurado.
  static Future<void> toggleMaximize() async {
    if (!isDesktop) return;
    try {
      final maximized = await isMaximized();
      if (maximized) {
        await restore();
      } else {
        await maximize();
      }
    } on Object catch (_) {}
  }

  /// Verifica se a janela está maximizada.
  static Future<bool> isMaximized() async {
    if (!isDesktop) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isMaximized');
      return res ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  /// Fecha a janela / encerra o aplicativo desktop.
  static Future<void> close() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('close');
    } on Object catch (_) {}
  }

  /// Inicia o arrasto nativo da janela através do cursor.
  static Future<void> startDragging() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('drag');
    } on Object catch (_) {}
  }

  /// Atualiza a cor da barra de título do Windows conforme o tema ativo.
  static Future<void> updateTitleBar(ThemeData theme) async {
    if (!isWindowsDesktop) return;

    try {
      final isDark = theme.brightness == Brightness.dark;
      final bg = theme.scaffoldBackgroundColor;
      final argb = bg.toARGB32();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;

      await _channel.invokeMethod('setTitleBarColor', {
        'r': r,
        'g': g,
        'b': b,
        'isDark': isDark,
      });
    } on Object catch (_) {
      // Ignora falhas em plataformas ou versões do Windows sem suporte a DWM Caption API
    }
  }
}
