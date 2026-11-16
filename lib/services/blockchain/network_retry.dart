import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// Falhas de rede transitórias (tempo esgotado, conexão recusada ou
/// interrompida, erro 5xx/429). Erros de validação nunca são repetidos.
bool isTransient(Object error) =>
    error is TimeoutException ||
    error is SocketException ||
    error is http.ClientException ||
    error is TransientHttpError;

class TransientHttpError implements Exception {
  /// Inicializa [TransientHttpError] com os dados recebidos.
  const TransientHttpError(this.statusCode);
  final int statusCode;

  /// Verifica se a falha corresponde aos critérios de nova tentativa.
  static bool matches(int status) => status == 429 || status >= 500;

  /// Gera a representação textual da instância.
  @override
  String toString() => 'TransientHttpError($statusCode)';
}

/// Executa uma consulta idempotente com novas tentativas e espera
/// crescente. Use apenas em leituras; transmissões não são repetidas.
Future<T> withRetry<T>(
  Future<T> Function() request, {
  int attempts = 3,
  Duration initialDelay = const Duration(milliseconds: 350),
}) async {
  var delay = initialDelay;
  for (var attempt = 1; ; attempt++) {
    try {
      return await request();
    } on Object catch (error) {
      if (attempt >= attempts || !isTransient(error)) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
