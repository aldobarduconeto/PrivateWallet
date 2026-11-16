import 'package:flutter/material.dart';

class MarketAsset {
  /// Inicializa [MarketAsset] com os dados recebidos.
  const MarketAsset({
    required this.symbol,
    required this.name,
    required this.priceBrl,
    required this.priceUsd,
    required this.change24h,
    required this.high24hBrl,
    required this.low24hBrl,
    required this.marketCapBrl,
    required this.sparkline,
    required this.color,
    required this.icon,
  });

  final String symbol;
  final String name;
  final double priceBrl;
  final double priceUsd;
  final double change24h;
  final double high24hBrl;
  final double low24hBrl;
  final String marketCapBrl;
  final List<double> sparkline;
  final Color color;
  final IconData icon;

  /// Indica a condição `isPositive` usada em market asset.
  bool get isPositive => change24h >= 0;
}

class PriceAlert {
  /// Inicializa [PriceAlert] com os dados recebidos.
  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPriceBrl,
    required this.isAbove,
    this.isActive = true,
    required this.createdAt,
    this.triggeredAt,
  });

  final String id;
  final String symbol;
  final double targetPriceBrl;
  final bool isAbove;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? triggeredAt;

  /// Cria uma cópia com os campos informados e preserva os demais.
  PriceAlert copyWith({bool? isActive, DateTime? triggeredAt}) => PriceAlert(
    id: id,
    symbol: symbol,
    targetPriceBrl: targetPriceBrl,
    isAbove: isAbove,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    triggeredAt: triggeredAt ?? this.triggeredAt,
  );

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'targetPriceBrl': targetPriceBrl,
    'isAbove': isAbove,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    if (triggeredAt != null) 'triggeredAt': triggeredAt!.toIso8601String(),
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    targetPriceBrl: (json['targetPriceBrl'] as num).toDouble(),
    isAbove: json['isAbove'] as bool? ?? true,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    triggeredAt: json['triggeredAt'] != null
        ? DateTime.parse(json['triggeredAt'] as String)
        : null,
  );
}
