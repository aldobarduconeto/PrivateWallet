import 'dart:typed_data';

import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../models/networks.dart';

/// Assina localmente a transferência Ethereum preparada.
Uint8List signEthereumTransfer({
  required Network network,
  required String secret,
  required EthereumAddress sender,
  required EthereumAddress recipient,
  required BigInt wei,
  required int nonce,
  required EtherAmount gasPrice,
  required int gasLimit,
}) {
  final key = EthPrivateKey.fromHex(secret);
  if (key.address != sender) {
    throw const FormatException(
      'A chave não corresponde ao endereço desta carteira.',
    );
  }
  return signTransactionRaw(
    Transaction(
      from: sender,
      to: recipient,
      value: EtherAmount.inWei(wei),
      nonce: nonce,
      gasPrice: gasPrice,
      maxGas: gasLimit,
      data: Uint8List(0),
    ),
    key,
    chainId: network.chainId,
  );
}
