import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import 'networks.dart';

enum MovementType {
  incoming('Entrada'),
  outgoing('Saída'),
  self('Entre contas próprias');

  /// Inicializa a configuração de chain movement.
  const MovementType(this.label);
  final String label;
}

/// Movimentação de uma carteira na blockchain (entrada ou saída), já
/// normalizada a partir do Esplora (Bitcoin) ou do indexador (Ethereum).
class ChainMovement {
  /// Inicializa [ChainMovement] com os dados recebidos.
  const ChainMovement({
    required this.hash,
    required this.type,
    required this.amount,
    required this.bitcoin,
    required this.networkId,
    this.fee,
    this.counterparty,
    this.time,
    this.confirmed = true,
    this.failed = false,
    this.local = false,
    this.paymentType,
  });

  final String hash;
  final MovementType type;

  /// Valor absoluto movimentado (sem a taxa), em wei ou satoshis.
  final BigInt amount;
  final bool bitcoin;
  final String networkId;

  /// Taxa paga pela carteira (somente em saídas).
  final BigInt? fee;
  final String? counterparty;

  /// Horário do bloco; nulo enquanto a transação estiver pendente.
  final DateTime? time;
  final bool confirmed;

  /// Execução revertida (Ethereum).
  final bool failed;

  /// Envio registrado neste aparelho e ainda não visto pelo indexador.
  final bool local;

  /// Tipo de pagamento ou categoria informada pelo usuário no envio (ex: Compra, Serviço, Aluguel).
  final String? paymentType;

  /// Retorna por ativo em uso.
  String get symbol => bitcoin ? 'BTC' : 'ETH';

  /// Formata o valor para exibição.
  String format(BigInt value) => bitcoin ? formatBtc(value) : formatEth(value);

  /// Efeito no saldo: positivo em entradas, negativo em saídas (com taxa).
  BigInt get net => switch (type) {
    MovementType.incoming => amount,
    MovementType.outgoing => -(amount + (fee ?? BigInt.zero)),
    MovementType.self => -(fee ?? BigInt.zero),
  };

  /// Retorna `explorer` para consulta em chain movement.
  Uri get explorer {
    if (bitcoin) return BitcoinChain.values.byName(networkId).explorer(hash);
    return Uri.https(Network.values.byName(networkId).explorer, '/tx/$hash');
  }

  /// Cria uma cópia com os campos informados e preserva os demais.
  ChainMovement copyWith({
    DateTime? time,
    bool? confirmed,
    String? paymentType,
  }) => ChainMovement(
    hash: hash,
    type: type,
    amount: amount,
    bitcoin: bitcoin,
    networkId: networkId,
    fee: fee,
    counterparty: counterparty,
    time: time ?? this.time,
    confirmed: confirmed ?? this.confirmed,
    failed: failed,
    local: local,
    paymentType: paymentType ?? this.paymentType,
  );
}

/// Uma página do extrato. `cursor` é nulo quando não há mais resultados.
typedef MovementPage = ({List<ChainMovement> items, String? cursor});
