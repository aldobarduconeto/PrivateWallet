import 'package:bitcoin_base/bitcoin_base.dart';

import '../models/networks.dart';
import 'bitcoin_codec.dart';

/// Assina localmente a transferência Bitcoin preparada.
BtcTransaction signBitcoinTransfer({
  required BitcoinChain chain,
  required ECPrivate key,
  required BitcoinAddress sender,
  required BitcoinAddress recipient,
  required List<BitcoinUtxo> inputs,
  required BigInt amount,
  required BigInt fee,
  required BigInt change,
}) {
  if (bitcoinAddressForKey(chain, key) != sender.address) {
    throw const FormatException('A chave não corresponde ao endereço Bitcoin.');
  }
  final details = UtxoAddressDetails(
    publicKey: key.getPublic().toHex(),
    address: sender.baseAddress,
  );
  final builder = BitcoinTransactionBuilder(
    outPuts: [
      BitcoinOutput(address: recipient.baseAddress, value: amount),
      if (change > BigInt.zero)
        BitcoinOutput(address: sender.baseAddress, value: change),
    ],
    fee: fee,
    network: chain.network,
    utxos: [
      for (final input in inputs)
        UtxoWithAddress(utxo: input, ownerDetails: details),
    ],
  );
  return builder.buildTransaction(
    (digest, _, _, sighash) => key.signECDSA(digest, sighash: sighash),
  );
}
