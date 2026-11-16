import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/market_asset.dart';
import 'system/notification_service.dart';

class CryptoMarketService {
  /// Inicializa [CryptoMarketService] com os dados recebidos.
  const CryptoMarketService([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _alertsKey = 'private_wallet.price_alerts.v1';

  static final List<MarketAsset> _defaultAssets = [
    const MarketAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      priceBrl: 412500.0,
      priceUsd: 74200.0,
      change24h: 3.42,
      high24hBrl: 418000.0,
      low24hBrl: 398200.0,
      marketCapBrl: '8.1 Tri',
      sparkline: [398000, 401000, 399500, 404000, 408000, 406000, 412500],
      color: Color(0xFFF7931A),
      icon: Icons.currency_bitcoin,
    ),
    const MarketAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      priceBrl: 18450.0,
      priceUsd: 3320.0,
      change24h: 2.15,
      high24hBrl: 18900.0,
      low24hBrl: 17800.0,
      marketCapBrl: '2.2 Tri',
      sparkline: [17800, 18100, 17950, 18300, 18200, 18550, 18450],
      color: Color(0xFF627EEA),
      icon: Icons.toll,
    ),
    const MarketAsset(
      symbol: 'SOL',
      name: 'Solana',
      priceBrl: 1085.0,
      priceUsd: 195.0,
      change24h: 5.80,
      high24hBrl: 1110.0,
      low24hBrl: 1015.0,
      marketCapBrl: '510 Bi',
      sparkline: [1020, 1040, 1030, 1060, 1090, 1070, 1085],
      color: Color(0xFF14F195),
      icon: Icons.flash_on,
    ),
    const MarketAsset(
      symbol: 'BNB',
      name: 'BNB Chain',
      priceBrl: 3450.0,
      priceUsd: 620.0,
      change24h: -0.85,
      high24hBrl: 3520.0,
      low24hBrl: 3410.0,
      marketCapBrl: '520 Bi',
      sparkline: [3510, 3490, 3480, 3440, 3460, 3430, 3450],
      color: Color(0xFFF3BA2F),
      icon: Icons.account_balance_wallet,
    ),
    const MarketAsset(
      symbol: 'USDT',
      name: 'Tether USD',
      priceBrl: 5.56,
      priceUsd: 1.00,
      change24h: 0.12,
      high24hBrl: 5.58,
      low24hBrl: 5.54,
      marketCapBrl: '680 Bi',
      sparkline: [5.55, 5.56, 5.55, 5.56, 5.57, 5.55, 5.56],
      color: Color(0xFF26A17B),
      icon: Icons.attach_money,
    ),
    const MarketAsset(
      symbol: 'XRP',
      name: 'Ripple',
      priceBrl: 3.25,
      priceUsd: 0.585,
      change24h: 1.45,
      high24hBrl: 3.32,
      low24hBrl: 3.18,
      marketCapBrl: '185 Bi',
      sparkline: [3.18, 3.20, 3.19, 3.23, 3.28, 3.22, 3.25],
      color: Color(0xFF23292F),
      icon: Icons.change_circle_outlined,
    ),
  ];

  /// Consulta os ativos.
  Future<List<MarketAsset>> fetchAssets() async {
    // Retorna a lista de ativos de mercado para consulta rápida e offline/online
    return _defaultAssets;
  }

  /// Carrega os alertas.
  Future<List<PriceAlert>> loadAlerts() async {
    final raw = await _storage.read(key: _alertsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => PriceAlert.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva os alertas.
  Future<void> saveAlerts(List<PriceAlert> alerts) async {
    final list = alerts.map((a) => a.toJson()).toList();
    await _storage.write(key: _alertsKey, value: jsonEncode(list));
  }

  /// Adiciona o alerta.
  Future<void> addAlert(PriceAlert alert) async {
    final alerts = await loadAlerts();
    alerts.insert(0, alert);
    await saveAlerts(alerts);
  }

  /// Remove o alerta.
  Future<void> removeAlert(String id) async {
    final alerts = await loadAlerts();
    alerts.removeWhere((a) => a.id == id);
    await saveAlerts(alerts);
  }

  /// Alterna o alerta.
  Future<void> toggleAlert(String id, bool active) async {
    final alerts = await loadAlerts();
    final index = alerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      alerts[index] = alerts[index].copyWith(isActive: active);
      await saveAlerts(alerts);
    }
  }

  /// Verifica se algum alerta ativo foi acionado pelos preços atuais
  Future<List<PriceAlert>> checkAndTriggerAlerts(
    List<MarketAsset> assets,
  ) async {
    final alerts = await loadAlerts();
    final triggered = <PriceAlert>[];
    var changed = false;

    for (var i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      if (!alert.isActive) continue;

      final asset = assets.firstWhere(
        (a) => a.symbol.toUpperCase() == alert.symbol.toUpperCase(),
        orElse: () => assets.first,
      );

      final price = asset.priceBrl;
      final shouldTrigger = alert.isAbove
          ? (price >= alert.targetPriceBrl)
          : (price <= alert.targetPriceBrl);

      if (shouldTrigger) {
        final updated = alert.copyWith(
          isActive: false,
          triggeredAt: DateTime.now(),
        );
        alerts[i] = updated;
        triggered.add(updated);
        changed = true;

        // Dispara notificação no dispositivo
        NotificationService.notify(
          title: '🚨 Alerta de Preço: ${alert.symbol}!',
          body: alert.isAbove
              ? '${alert.symbol} subiu para R\$ ${price.toStringAsFixed(2)} (alvo: R\$ ${alert.targetPriceBrl.toStringAsFixed(2)})'
              : '${alert.symbol} caiu para R\$ ${price.toStringAsFixed(2)} (alvo: R\$ ${alert.targetPriceBrl.toStringAsFixed(2)})',
        );
      }
    }

    if (changed) {
      await saveAlerts(alerts);
    }
    return triggered;
  }
}
