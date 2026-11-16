import 'package:flutter/material.dart';

enum AutoDebitFrequency {
  weekly('Semanal', 7),
  biweekly('Quinzenal', 14),
  monthly('Mensal', 30),
  quarterly('Trimestral', 90),
  yearly('Anual', 365);

  /// Inicializa a configuração de auto debit plan.
  const AutoDebitFrequency(this.label, this.days);
  final String label;
  final int days;
}

enum AutoDebitCategory {
  rent('Aluguel', Icons.home_outlined),
  subscription('Assinatura', Icons.subscriptions_outlined),
  service('Serviço', Icons.build_circle_outlined),
  donation('Doação', Icons.favorite_outline),
  other('Outro', Icons.repeat);

  /// Inicializa a configuração de auto debit plan.
  const AutoDebitCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Converte o nome persistido para a opção de recorrência correspondente.
  static AutoDebitCategory fromName(String? name) {
    return AutoDebitCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == (name ?? '').toLowerCase(),
      orElse: () => AutoDebitCategory.other,
    );
  }
}

class AutoDebitExecution {
  /// Inicializa [AutoDebitExecution] com os dados recebidos.
  const AutoDebitExecution({
    required this.id,
    required this.timestamp,
    required this.txHash,
    required this.amount,
    required this.symbol,
    required this.success,
    this.errorMessage,
  });

  final String id;
  final DateTime timestamp;
  final String txHash;
  final BigInt amount;
  final String symbol;
  final bool success;
  final String? errorMessage;

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'txHash': txHash,
    'amount': amount.toString(),
    'symbol': symbol,
    'success': success,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory AutoDebitExecution.fromJson(Map<String, dynamic> json) {
    return AutoDebitExecution(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      txHash: (json['txHash'] as String?) ?? '',
      amount: BigInt.parse(json['amount'] as String),
      symbol: (json['symbol'] as String?) ?? 'ETH',
      success: (json['success'] as bool?) ?? true,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class AutoDebitPlan {
  /// Inicializa [AutoDebitPlan] com os dados recebidos.
  const AutoDebitPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.recipientAddress,
    this.recipientName,
    required this.amount,
    required this.symbol,
    required this.frequency,
    required this.created,
    required this.nextExecution,
    this.lastExecution,
    required this.isActive,
    this.autoExecution = true,
    this.walletAddress,
    this.executions = const [],
  });

  final String id;
  final String title;
  final AutoDebitCategory category;
  final String recipientAddress;
  final String? recipientName;
  final BigInt amount;
  final String symbol; // 'ETH' ou 'BTC'
  final AutoDebitFrequency frequency;
  final DateTime created;
  final DateTime nextExecution;
  final DateTime? lastExecution;
  final bool isActive;
  final bool autoExecution;
  final String? walletAddress;
  final List<AutoDebitExecution> executions;

  /// Retorna se o débito está vencido e pronto para execução.
  bool get isDue => isActive && DateTime.now().isAfter(nextExecution);

  /// Retorna dias restantes até a próxima cobrança.
  int get daysUntilNext {
    final diff = nextExecution.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Cancela o débito automático a qualquer momento.
  AutoDebitPlan cancel() => copyWith(isActive: false);

  /// Reativa o débito automático.
  AutoDebitPlan resume() => copyWith(isActive: true);

  /// Calcula a próxima data com base na frequência após uma execução.
  DateTime calculateNextDate() {
    return DateTime.now().add(Duration(days: frequency.days));
  }

  /// Registra uma nova execução concluída.
  AutoDebitPlan recordExecution(AutoDebitExecution execution) {
    final updatedList = [execution, ...executions];
    return copyWith(
      lastExecution: execution.timestamp,
      nextExecution: calculateNextDate(),
      executions: updatedList,
    );
  }

  /// Cria uma cópia com os campos informados e preserva os demais.
  AutoDebitPlan copyWith({
    String? id,
    String? title,
    AutoDebitCategory? category,
    String? recipientAddress,
    String? recipientName,
    BigInt? amount,
    String? symbol,
    AutoDebitFrequency? frequency,
    DateTime? created,
    DateTime? nextExecution,
    DateTime? lastExecution,
    bool? isActive,
    bool? autoExecution,
    String? walletAddress,
    List<AutoDebitExecution>? executions,
  }) {
    return AutoDebitPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      recipientName: recipientName ?? this.recipientName,
      amount: amount ?? this.amount,
      symbol: symbol ?? this.symbol,
      frequency: frequency ?? this.frequency,
      created: created ?? this.created,
      nextExecution: nextExecution ?? this.nextExecution,
      lastExecution: lastExecution ?? this.lastExecution,
      isActive: isActive ?? this.isActive,
      autoExecution: autoExecution ?? this.autoExecution,
      walletAddress: walletAddress ?? this.walletAddress,
      executions: executions ?? this.executions,
    );
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'recipientAddress': recipientAddress,
    if (recipientName != null) 'recipientName': recipientName,
    'amount': amount.toString(),
    'symbol': symbol,
    'frequency': frequency.name,
    'created': created.toIso8601String(),
    'nextExecution': nextExecution.toIso8601String(),
    if (lastExecution != null)
      'lastExecution': lastExecution!.toIso8601String(),
    'isActive': isActive,
    'autoExecution': autoExecution,
    if (walletAddress != null) 'walletAddress': walletAddress,
    'executions': executions.map((e) => e.toJson()).toList(),
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory AutoDebitPlan.fromJson(Map<String, dynamic> json) {
    return AutoDebitPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      category: AutoDebitCategory.fromName(json['category'] as String?),
      recipientAddress: json['recipientAddress'] as String,
      recipientName: json['recipientName'] as String?,
      amount: BigInt.parse(json['amount'] as String),
      symbol: (json['symbol'] as String?) ?? 'ETH',
      frequency: AutoDebitFrequency.values.firstWhere(
        (f) => f.name == (json['frequency'] as String?),
        orElse: () => AutoDebitFrequency.monthly,
      ),
      created: DateTime.parse(json['created'] as String),
      nextExecution: DateTime.parse(json['nextExecution'] as String),
      lastExecution: json['lastExecution'] != null
          ? DateTime.parse(json['lastExecution'] as String)
          : null,
      isActive: (json['isActive'] as bool?) ?? true,
      autoExecution: (json['autoExecution'] as bool?) ?? true,
      walletAddress: json['walletAddress'] as String?,
      executions:
          (json['executions'] as List<dynamic>?)
              ?.map(
                (e) => AutoDebitExecution.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}
