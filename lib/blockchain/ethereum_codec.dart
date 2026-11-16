import 'package:wallet/wallet.dart';

import '../models/networks.dart';

final _weiPerEth = BigInt.from(10).pow(18);

/// Converte um valor decimal em ETH para wei.
BigInt parseEth(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,60}(\.\d{1,18})?$').hasMatch(text)) {
    throw const FormatException(
      'Informe um valor em ETH com até 18 casas decimais.',
    );
  }
  final parts = text.split('.');
  final fraction = parts.length == 2 ? parts.last : '';
  final wei =
      BigInt.parse(parts.first) * _weiPerEth +
      BigInt.parse(fraction.padRight(18, '0'));
  if (wei <= BigInt.zero || wei.bitLength > 256) {
    throw const FormatException('Informe um valor positivo válido.');
  }
  return wei;
}

/// Formata wei como um valor decimal em ETH.
String formatEth(BigInt wei) {
  final whole = wei ~/ _weiPerEth;
  final fraction = (wei % _weiPerEth)
      .toString()
      .padLeft(18, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole,$fraction';
}

/// Valida e interpreta o endereço Ethereum.
EthereumAddress parseAddress(String input) {
  final text = input.trim();
  if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(text) ||
      text == '0x${'0' * 40}') {
    throw const FormatException('Informe um endereço Ethereum válido.');
  }
  final address = EthereumAddress.fromHex(text);
  final body = text.substring(2);
  if (body != body.toLowerCase() &&
      body != body.toUpperCase() &&
      address.eip55With0x != text) {
    throw const FormatException(
      'Confira a capitalização do endereço Ethereum.',
    );
  }
  return address;
}

/// Gera a URI Ethereum para o endereço, a rede e o valor solicitado.
String paymentLink(Network network, EthereumAddress address, BigInt? wei) =>
    'ethereum:${address.eip55With0x}@${network.chainId}'
    '${wei == null ? '' : '?value=$wei'}';
