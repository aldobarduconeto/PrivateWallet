import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import 'networks.dart';

class WalletActivity {
  /// Inicializa [WalletActivity] com os dados recebidos.
  WalletActivity({
    required this.hash,
    this.networkId = '',
    this.bitcoin = false,
    this.sender = '',
    required this.recipient,
    required this.amount,
    BigInt? fee,
    BigInt? estimatedFee,
    required this.created,
    this.purchaseName,
    this.paymentType,
    this.contactName,
  }) : fee = fee ?? estimatedFee ?? BigInt.zero;

  /// Reconstrói a instância a partir dos dados persistidos.
  factory WalletActivity.fromJson(Map<String, dynamic> json) {
    final purchase = json['purchaseName'] as String?;
    final pType = json['paymentType'] as String? ?? purchase;
    return WalletActivity(
      hash: json['hash'] as String,
      networkId: json['network'] as String? ?? '',
      bitcoin: json['bitcoin'] as bool? ?? false,
      sender: json['sender'] as String? ?? '',
      recipient: json['recipient'] as String? ?? '',
      amount: BigInt.parse(json['amount'] as String),
      fee: BigInt.parse(json['fee'] as String),
      created: DateTime.parse(json['created'] as String),
      purchaseName: purchase,
      paymentType: pType,
      contactName: json['contactName'] as String?,
    );
  }

  final String hash;
  final String networkId;
  final bool bitcoin;
  final String sender;
  final String recipient;
  final BigInt amount;
  final BigInt fee;
  final DateTime created;
  final String? purchaseName;

  /// Tipo ou categoria de pagamento informado pelo usuário (ex: Compra, Serviço, Aluguel, Pessoal).
  final String? paymentType;

  /// Nome do contato salvo na agenda (opcional)
  final String? contactName;

  /// Retorna `to` para consulta em wallet activity.
  String get to => recipient;

  /// Retorna `estimatedFee` para consulta em wallet activity.
  BigInt get estimatedFee => fee;

  /// Retorna por ativo em uso.
  String get symbol => bitcoin ? 'BTC' : 'ETH';

  /// Formata o valor para exibição.
  String format(BigInt value) => bitcoin ? formatBtc(value) : formatEth(value);

  /// Retorna `explorer` para consulta em wallet activity.
  Uri get explorer {
    if (bitcoin) return BitcoinChain.values.byName(networkId).explorer(hash);
    return Uri.https(Network.values.byName(networkId).explorer, '/tx/$hash');
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, Object> toJson() => {
    'hash': hash,
    'network': networkId,
    'bitcoin': bitcoin,
    'sender': sender,
    'recipient': recipient,
    'amount': amount.toString(),
    'fee': fee.toString(),
    'created': created.toUtc().toIso8601String(),
    // ignore: use_null_aware_elements
    if (purchaseName != null) 'purchaseName': purchaseName!,
    // ignore: use_null_aware_elements
    if (paymentType != null) 'paymentType': paymentType!,
  };
}
