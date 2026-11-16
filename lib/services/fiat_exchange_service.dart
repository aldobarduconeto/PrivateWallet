import 'dart:convert';

import 'package:http/http.dart' as http;

class FiatExchangeService {
  static final instance = FiatExchangeService();
  static final attribution = Uri.https('www.exchangerate-api.com');
  static const _fallback = {'USD': 1.0};

  Map<String, double> _rates = _fallback;
  DateTime? _refreshAt;
  Future<Map<String, double>>? _pending;

  /// Reutiliza a consulta em andamento ou o cache antes de buscar novas taxas.
  Future<Map<String, double>> rates() {
    final pending = _pending;
    if (pending != null) return pending;
    final refreshAt = _refreshAt;
    if (refreshAt != null && DateTime.now().isBefore(refreshAt)) {
      return Future.value(_rates);
    }
    return _pending = _fetch().whenComplete(() => _pending = null);
  }

  /// Busca e valida as taxas de câmbio do provedor.
  Future<Map<String, double>> _fetch() async {
    _refreshAt = DateTime.now().add(const Duration(minutes: 1));
    try {
      final response = await http
          .get(Uri.https('open.er-api.com', '/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return _rates;
      final json = jsonDecode(response.body);
      if (json is! Map ||
          json['result'] != 'success' ||
          json['base_code'] != 'USD') {
        return _rates;
      }
      final rates = json['rates'];
      if (rates is! Map<String, dynamic>) return _rates;
      final validated = <String, double>{
        for (final MapEntry(:key, :value) in rates.entries)
          if (RegExp(r'^[A-Z]{3}$').hasMatch(key) &&
              value is num &&
              value.isFinite &&
              value > 0)
            key: value.toDouble(),
      };
      if (validated.length <= 2) return _rates;
      _rates = Map.unmodifiable({..._fallback, ...validated});
      _refreshAt = DateTime.now().add(const Duration(hours: 24));
      return _rates;
    } on Exception {
      return _rates;
    }
  }
}
