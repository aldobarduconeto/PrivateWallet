class FinancialGoal {
  /// Inicializa [FinancialGoal] com os dados recebidos.
  const FinancialGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.symbol,
    required this.createdAt,
    this.targetDate,
  });

  /// Reconstrói a instância a partir dos dados persistidos.
  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    targetAmount: BigInt.parse(json['targetAmount'] as String),
    symbol: json['symbol'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    targetDate: json['targetDate'] != null
        ? DateTime.parse(json['targetDate'] as String)
        : null,
  );

  final String id;
  final String title;
  final BigInt targetAmount;
  final String symbol; // 'BTC' ou 'ETH'
  final DateTime createdAt;
  final DateTime? targetDate;

  /// Retorna o percentual concluído (0.0 a 1.0 ou mais) baseado no saldo atual.
  double progress(BigInt currentBalance) {
    if (targetAmount <= BigInt.zero) return 0.0;
    final p = currentBalance / targetAmount;
    return p < 0 ? 0.0 : p;
  }

  /// Indica se a meta foi atingida.
  bool isCompleted(BigInt currentBalance) => currentBalance >= targetAmount;

  /// Calcula o progresso da meta com o saldo informado.
  double progressWith(double currentBalanceCrypto) {
    final target = targetAmount.toDouble();
    if (target <= 0) return 0.0;
    return (currentBalanceCrypto / target).clamp(0.0, 1.0);
  }

  /// Verifica se o saldo informado alcança o objetivo da meta.
  bool isCompletedWith(double currentBalanceCrypto) {
    final target = targetAmount.toDouble();
    return currentBalanceCrypto >= target && target > 0;
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetAmount': targetAmount.toString(),
    'symbol': symbol,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (targetDate != null) 'targetDate': targetDate!.toUtc().toIso8601String(),
  };
}
