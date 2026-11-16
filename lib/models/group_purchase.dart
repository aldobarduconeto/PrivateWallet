/// Representa um participante de uma compra conjunta/racha coletivo.
class GroupPurchaseMember {
  /// Inicializa [GroupPurchaseMember] com os dados recebidos.
  const GroupPurchaseMember({
    required this.id,
    required this.name,
    this.username,
    this.uniqueId,
    this.address,
    required this.shareAmount,
    this.isPaid = false,
    this.paidAt,
    this.txHash,
    this.isOrganizer = false,
  });

  final String id;
  final String name;
  final String? username;
  final String? uniqueId;
  final String? address;
  final double shareAmount;
  final bool isPaid;
  final DateTime? paidAt;
  final String? txHash;
  final bool isOrganizer;

  /// Cria uma cópia com os campos informados e preserva os demais.
  GroupPurchaseMember copyWith({
    String? name,
    String? username,
    String? uniqueId,
    String? address,
    double? shareAmount,
    bool? isPaid,
    DateTime? paidAt,
    String? txHash,
    bool? isOrganizer,
  }) {
    return GroupPurchaseMember(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      uniqueId: uniqueId ?? this.uniqueId,
      address: address ?? this.address,
      shareAmount: shareAmount ?? this.shareAmount,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      txHash: txHash ?? this.txHash,
      isOrganizer: isOrganizer ?? this.isOrganizer,
    );
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (username != null) 'username': username,
    if (uniqueId != null) 'uniqueId': uniqueId,
    if (address != null) 'address': address,
    'shareAmount': shareAmount,
    'isPaid': isPaid,
    if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
    if (txHash != null) 'txHash': txHash,
    'isOrganizer': isOrganizer,
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory GroupPurchaseMember.fromJson(Map<String, dynamic> json) {
    return GroupPurchaseMember(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String?,
      uniqueId: json['uniqueId'] as String?,
      address: json['address'] as String?,
      shareAmount: (json['shareAmount'] as num).toDouble(),
      isPaid: json['isPaid'] as bool? ?? false,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      txHash: json['txHash'] as String?,
      isOrganizer: json['isOrganizer'] as bool? ?? false,
    );
  }
}

/// Representa uma Compra Conjunta (Group Buy / Racha Coletivo Soberano).
class GroupPurchase {
  /// Inicializa [GroupPurchase] com os dados recebidos.
  const GroupPurchase({
    required this.id,
    required this.title,
    this.description = '',
    required this.asset, // 'ETH' ou 'BTC'
    required this.totalAmount,
    required this.createdAt,
    required this.members,
    this.fiatReference,
  });

  final String id;
  final String title;
  final String description;
  final String asset; // 'ETH' ou 'BTC'
  final double totalAmount;
  final DateTime createdAt;
  final List<GroupPurchaseMember> members;
  final String? fiatReference;

  /// Retorna `totalMembers` para consulta em compras conjuntas.
  int get totalMembers => members.length;

  /// Retorna `paidMembersCount` para consulta em compras conjuntas.
  int get paidMembersCount => members.where((m) => m.isPaid).length;

  /// Retorna `totalPaidAmount` para consulta em compras conjuntas.
  double get totalPaidAmount =>
      members.where((m) => m.isPaid).fold(0.0, (acc, m) => acc + m.shareAmount);

  /// Retorna `progress` para consulta em compras conjuntas.
  double get progress =>
      totalAmount <= 0 ? 1.0 : (totalPaidAmount / totalAmount).clamp(0.0, 1.0);

  /// Indica a condição `isSettled` usada em compras conjuntas.
  bool get isSettled => members.isNotEmpty && members.every((m) => m.isPaid);

  /// Cria uma cópia com os campos informados e preserva os demais.
  GroupPurchase copyWith({
    String? title,
    String? description,
    String? asset,
    double? totalAmount,
    DateTime? createdAt,
    List<GroupPurchaseMember>? members,
    String? fiatReference,
  }) {
    return GroupPurchase(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      asset: asset ?? this.asset,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      fiatReference: fiatReference ?? this.fiatReference,
    );
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'asset': asset,
    'totalAmount': totalAmount,
    'createdAt': createdAt.toIso8601String(),
    'members': members.map((m) => m.toJson()).toList(),
    if (fiatReference != null) 'fiatReference': fiatReference,
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory GroupPurchase.fromJson(Map<String, dynamic> json) {
    return GroupPurchase(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      asset: json['asset'] as String? ?? 'ETH',
      totalAmount: (json['totalAmount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      members: (json['members'] as List<dynamic>)
          .map((m) => GroupPurchaseMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      fiatReference: json['fiatReference'] as String?,
    );
  }
}
