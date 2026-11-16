import 'dart:math';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:web3dart/web3dart.dart';

import '../models/networks.dart';
import 'bitcoin_codec.dart';

/// Par de chaves e endereços unificado para Ethereum e Bitcoin.
class MultiCoinKeys {
  /// Inicializa [MultiCoinKeys] com os dados recebidos.
  const MultiCoinKeys({
    required this.hexSecret,
    required this.ethAddress,
    required this.btcAddress,
    required this.btcWif,
    required this.bitcoinChain,
  });

  final String hexSecret;
  final String ethAddress;
  final String btcAddress;
  final String btcWif;
  final BitcoinChain bitcoinChain;

  /// Gera um novo par de chaves Multi-Coin com entropia criptográfica segura.
  factory MultiCoinKeys.generate({
    BitcoinChain bitcoin = BitcoinChain.testnet4,
  }) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return MultiCoinKeys.fromHexSecret(hex, bitcoin: bitcoin);
  }

  /// Deriva os endereços Ethereum e Bitcoin a partir de uma chave privada hex de 32 bytes.
  factory MultiCoinKeys.fromHexSecret(
    String hexInput, {
    BitcoinChain bitcoin = BitcoinChain.testnet4,
  }) {
    final cleanHex = hexInput.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(cleanHex)) {
      throw const FormatException(
        'A chave deve conter 64 caracteres hexadecimais.',
      );
    }

    // 1. Derivação Ethereum
    final ethKey = EthPrivateKey.fromHex(cleanHex);
    final ethAddr = ethKey.address.eip55With0x;

    // 2. Derivação Bitcoin SegWit nativo (P2WPKH)
    final btcKey = ECPrivate.fromHex(cleanHex);
    final btcAddr = bitcoinAddressForKey(bitcoin, btcKey);
    final wif = btcKey.toWif(network: bitcoin.network);

    return MultiCoinKeys(
      hexSecret: cleanHex,
      ethAddress: ethAddr,
      btcAddress: btcAddr,
      btcWif: wif,
      bitcoinChain: bitcoin,
    );
  }
}
