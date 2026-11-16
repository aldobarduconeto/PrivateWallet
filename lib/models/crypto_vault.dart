/// Representa um cofre/gaveta de reserva cripto virtual para organização patrimonial.
///
/// IMPORTANTE: As caixinhas e cofres virtuais são divisões puramente lógicas e
/// visuais no próprio dispositivo para controle, separação de metas e disciplina
/// mental (HODL). NÃO são investimentos de renda fixa, NÃO rendem juros, dividendos
/// ou qualquer remuneração financeira. Os fundos continuam sob a autocustódia
/// do usuário na blockchain.
class CryptoVault {
  /// Inicializa [CryptoVault] com os dados recebidos.
  const CryptoVault({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.allocatedAmount,
    required this.symbol,
    this.lockedUntil,
    this.iconName = 'savings',
    required this.createdAt,
  });

  final String id;
  final String title;
  final double targetAmount;
  final double allocatedAmount;
  final String symbol;
  final DateTime? lockedUntil;
  final String iconName;
  final DateTime createdAt;

  /// Retorna `progress` para consulta em crypto vault.
  double get progress => targetAmount <= 0
      ? 0.0
      : (allocatedAmount / targetAmount).clamp(0.0, 1.0);

  /// Indica se a meta foi atingida.
  bool get isCompleted => allocatedAmount >= targetAmount && targetAmount > 0;

  /// Indica a condição `isLocked` usada em crypto vault.
  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  /// Calcula os dias restantes até o desbloqueio do cofre.
  int get remainingLockDays {
    if (lockedUntil == null) return 0;
    final diff = lockedUntil!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Cria uma cópia com os campos informados e preserva os demais.
  CryptoVault copyWith({
    String? title,
    double? targetAmount,
    double? allocatedAmount,
    String? symbol,
    DateTime? lockedUntil,
    String? iconName,
  }) => CryptoVault(
    id: id,
    title: title ?? this.title,
    targetAmount: targetAmount ?? this.targetAmount,
    allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    symbol: symbol ?? this.symbol,
    lockedUntil: lockedUntil ?? this.lockedUntil,
    iconName: iconName ?? this.iconName,
    createdAt: createdAt,
  );

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetAmount': targetAmount,
    'allocatedAmount': allocatedAmount,
    'symbol': symbol,
    'lockedUntil': lockedUntil?.toIso8601String(),
    'iconName': iconName,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory CryptoVault.fromJson(Map<String, dynamic> json) => CryptoVault(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Cofre Sem Nome',
    targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
    allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
    symbol: json['symbol'] as String? ?? 'BTC',
    lockedUntil: json['lockedUntil'] != null
        ? DateTime.tryParse(json['lockedUntil'] as String)
        : null,
    iconName: json['iconName'] as String? ?? 'savings',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}
