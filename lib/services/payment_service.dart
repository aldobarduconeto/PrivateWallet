import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../models/networks.dart';

typedef Payment = ({String to, BigInt amount});

/// Interpreta o pagamento.
Payment parsePayment(
  String destination,
  String amount, {
  required Network ethereum,
  BitcoinChain? bitcoin,
}) {
  var address = destination.trim();
  BigInt? requested;
  if (address.contains(':')) {
    if (address.length > 1024) {
      throw const FormatException('Link de pagamento inválido.');
    }
    final uri = Uri.parse(address);
    if (uri.hasAuthority ||
        uri.hasFragment ||
        uri.scheme != (bitcoin == null ? 'ethereum' : 'bitcoin')) {
      throw const FormatException(
        'Link incompatível com a carteira selecionada.',
      );
    }
    final params = uri
        .replace(query: uri.query.replaceAll('+', '%2B'))
        .queryParametersAll;
    final supported = bitcoin == null
        ? {'value'}
        : {'amount', 'tb', 'label', 'message'};
    if (params.entries.any(
      (entry) => !supported.contains(entry.key) || entry.value.length != 1,
    )) {
      throw const FormatException(
        'O link contém instruções de pagamento não suportadas.',
      );
    }
    address = uri.path;
    if (bitcoin == null) {
      final target = RegExp(r'^(?:pay-)?(0x[0-9a-fA-F]{40})(?:@([0-9]+))?$')
          .firstMatch(address);
      if (target == null) {
        throw const FormatException(
          'Use um link de transferência de ETH nativo.',
        );
      }
      final chain = target[2];
      if (chain != null && int.tryParse(chain) != ethereum.chainId) {
        throw const FormatException('O link Ethereum pertence a outra rede.');
      }
      if (chain == null && ethereum != Network.mainnet) {
        throw const FormatException(
          'O link não identifica a rede de teste Ethereum.',
        );
      }
      address = target[1]!;
      if (params['value'] case [final wei]) requested = _parseWei(wei);
    } else {
      if (params['tb'] case [final testAddress]) {
        if (bitcoin != BitcoinChain.testnet4 ||
            address.isNotEmpty ||
            !testAddress.toLowerCase().startsWith('tb1')) {
          throw const FormatException('O link Bitcoin pertence a outra rede.');
        }
        address = testAddress;
      }
      if (params['amount'] case [final btc]) {
        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(btc)) {
          throw const FormatException('Valor Bitcoin inválido no link.');
        }
        requested = parseBtc(btc);
      }
    }
  }

  final to = bitcoin == null
      ? parseAddress(address).eip55With0x
      : parseBitcoinAddress(bitcoin, address).address;
  final manual = amount.trim().isEmpty
      ? null
      : bitcoin == null
      ? parseEth(amount)
      : parseBtc(amount);
  if (requested != null && manual != null && manual != requested) {
    throw const FormatException('O valor digitado difere do valor do link.');
  }
  final total = requested ?? manual;
  if (total == null) {
    throw const FormatException('Informe o valor do pagamento.');
  }
  return (to: to, amount: total);
}

/// Interpreta em wei a resposta numérica recebida da rede.
BigInt _parseWei(String text) {
  final match = RegExp(r'^(\d{1,78})(?:\.(\d{1,78}))?(?:[eE]([+-]?\d{1,3}))?$')
      .firstMatch(text);
  if (match == null) {
    throw const FormatException('Valor Ethereum inválido no link.');
  }
  final fraction = match[2] ?? '';
  final exponent = int.parse(match[3] ?? '0') - fraction.length;
  var value = BigInt.parse('${match[1]}$fraction');
  if (exponent >= 0 && exponent <= 77) {
    value *= BigInt.from(10).pow(exponent);
  } else if (exponent < 0 && exponent >= -156) {
    final divisor = BigInt.from(10).pow(-exponent);
    if (value % divisor != BigInt.zero) {
      throw const FormatException('O link contém uma fração de wei.');
    }
    value ~/= divisor;
  } else {
    throw const FormatException('Valor Ethereum fora dos limites.');
  }
  if (value <= BigInt.zero || value.bitLength > 256) {
    throw const FormatException('Valor Ethereum fora dos limites.');
  }
  return value;
}
