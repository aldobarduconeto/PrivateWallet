import 'package:bitcoin_base/bitcoin_base.dart';

import '../models/networks.dart';

final _satoshisPerBtc = BigInt.from(100000000);
const maxSatoshis = 2100000000000000;

/// Converte um valor decimal em BTC para satoshis.
BigInt parseBtc(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,8}(\.\d{1,8})?$').hasMatch(value)) {
    throw const FormatException(
      'Informe um valor em BTC com até 8 casas decimais.',
    );
  }
  final parts = value.split('.');
  final whole = BigInt.parse(parts.first) * _satoshisPerBtc;
  final fraction = parts.length == 2
      ? BigInt.parse(parts.last.padRight(8, '0'))
      : BigInt.zero;
  final sats = whole + fraction;
  if (sats <= BigInt.zero || sats > BigInt.from(maxSatoshis)) {
    throw const FormatException('Informe um valor positivo válido.');
  }
  return sats;
}

/// Formata satoshis como um valor decimal em BTC.
String formatBtc(BigInt sats, {String separator = ','}) {
  final whole = sats ~/ _satoshisPerBtc;
  final fraction = (sats % _satoshisPerBtc)
      .toString()
      .padLeft(8, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole$separator$fraction';
}

/// Valida e interpreta um endereço Bitcoin para a rede indicada.
BitcoinAddress parseBitcoinAddress(BitcoinChain chain, String input) {
  try {
    final address = BitcoinAddress(input.trim(), network: chain.network);
    return BitcoinAddress.fromBaseAddress(
      address.baseAddress,
      network: chain.network,
    );
  } on Exception {
    throw const FormatException(
      'Informe um endereço Bitcoin válido para esta rede.',
    );
  }
}

/// Gera a URI Bitcoin para o endereço e o valor solicitado.
String bitcoinPaymentLink(BitcoinChain chain, String address, BigInt? amount) {
  final amountText = amount == null ? null : formatBtc(amount, separator: '.');
  if (chain == BitcoinChain.testnet4 && address.startsWith('tb1')) {
    return 'bitcoin:?tb=$address${amountText == null ? '' : '&amount=$amountText'}';
  }
  return 'bitcoin:$address${amountText == null ? '' : '?amount=$amountText'}';
}

/// Importa `bitcoin key` no fluxo de bitcoin codec.
ECPrivate importBitcoinKey(BitcoinChain chain, String input) {
  try {
    final key = ECPrivate.fromWif(
      input.trim(),
      netVersion: chain.network.wifNetVer,
    );
    if (key.toWif(network: chain.network) == input.trim()) return key;
  } on Exception {
    // All invalid keys get the same message without revealing key material.
  }
  throw const FormatException(
    'Informe uma chave WIF comprimida válida para esta rede.',
  );
}

/// Deriva o endereço Bitcoin correspondente à chave e à rede informadas.
String bitcoinAddressForKey(BitcoinChain chain, ECPrivate key) =>
    key.getPublic().toSegwitAddress().toAddress(chain.network);

/// Gera uma chave privada para uma carteira Bitcoin.
String newBitcoinKey(BitcoinChain chain) =>
    ECPrivate.random().toWif(network: chain.network);
