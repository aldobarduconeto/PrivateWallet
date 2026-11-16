/// Orçamento e limites de gastos mensais por ativo (BTC / ETH).
class SpendingBudget {
  /// Inicializa [SpendingBudget] com os dados recebidos.
  const SpendingBudget({
    required this.symbol,
    required this.monthlyLimit,
    required this.updatedAt,
  });

  final String symbol;
  final double monthlyLimit;
  final DateTime updatedAt;

  /// Indica a condição `isEnabled` usada em spending budget.
  bool get isEnabled => monthlyLimit > 0;

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'monthlyLimit': monthlyLimit,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory SpendingBudget.fromJson(Map<String, dynamic> json) => SpendingBudget(
    symbol: json['symbol'] as String? ?? 'BTC',
    monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 0.0,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}
