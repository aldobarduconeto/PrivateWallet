import 'package:flutter/material.dart';

/// Estilos de contraste e acento de cor personalizáveis pelo usuário.
enum AppContrastTheme {
  standard('Índigo Private (Padrão)', Color(0xff5144c9)),
  cryptoGreen('Verde Cripto', Color(0xff10b981)),
  bitcoinGold('Ouro Bitcoin', Color(0xfff59e0b)),
  ethereumBlue('Azul Ethereum', Color(0xff0ea5e9)),
  neonViolet('Violeta Cripto', Color(0xff8b5cf6)),
  highContrast('Alto Contraste OLED', Color(0xff000000));

  /// Inicializa a configuração de app contrast theme.
  const AppContrastTheme(this.label, this.seedColor);
  final String label;
  final Color seedColor;
}
