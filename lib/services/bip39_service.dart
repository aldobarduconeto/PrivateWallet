import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'bip39_words.dart';

/// Serviço padrão de Frases Mnemônicas de Recuperação (BIP-39).
/// Suporta geração, validação e derivação determinística de chaves soberanas para 12 e 24 palavras.
abstract final class Bip39Service {
  static final Map<String, int> _wordIndexMap = {
    for (var i = 0; i < bip39WordList.length; i++) bip39WordList[i]: i,
  };

  /// Quantidade total de palavras no vocabulário oficial BIP-39 (2048 palavras).
  static int get totalWords => bip39WordList.length;

  /// Gera uma nova frase mnemônica criptograficamente segura de [words] palavras (12 ou 24).
  static String generateMnemonic({int words = 12}) {
    if (words != 12 && words != 24) {
      throw ArgumentError('A frase mnemônica deve ter 12 ou 24 palavras.');
    }

    final entropyBytesCount = words == 12 ? 16 : 32;
    final rnd = Random.secure();
    final entropy = Uint8List(entropyBytesCount);
    for (var i = 0; i < entropyBytesCount; i++) {
      entropy[i] = rnd.nextInt(256);
    }

    return entropyToMnemonic(entropy);
  }

  /// Converte bytes de entropia (16 ou 32 bytes) em frase mnemônica BIP-39.
  static String entropyToMnemonic(Uint8List entropy) {
    if (entropy.length != 16 && entropy.length != 32) {
      throw ArgumentError('A entropia deve ter 16 bytes (12 palavras) ou 32 bytes (24 palavras).');
    }

    // Calcula Checksum = primeiros (entropy.length * 8 / 32) bits do SHA-256
    final hash = sha256.convert(entropy).bytes;
    final checksumLengthBits = entropy.length ~/ 4; // 4 bits para 16 bytes, 8 bits para 32 bytes

    // Converte os bytes de entropia para uma cadeia de bits
    final buffer = StringBuffer();
    for (final byte in entropy) {
      buffer.write(byte.toRadixString(2).padLeft(8, '0'));
    }

    // Converte os primeiros bits do checksum para a cadeia
    final checksumBits = hash[0].toRadixString(2).padLeft(8, '0').substring(0, checksumLengthBits);
    buffer.write(checksumBits);

    final totalBits = buffer.toString();
    final mnemonicWords = <String>[];

    // Divide em blocos de 11 bits (índices de 0 a 2047)
    for (var i = 0; i < totalBits.length; i += 11) {
      final chunk = totalBits.substring(i, i + 11);
      final index = int.parse(chunk, radix: 2);
      mnemonicWords.add(bip39WordList[index]);
    }

    return mnemonicWords.join(' ');
  }

  /// Converte uma frase mnemônica de 12 ou 24 palavras de volta para os bytes de entropia originais.
  static Uint8List mnemonicToEntropy(String mnemonic) {
    final words = mnemonic.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length != 12 && words.length != 24) {
      throw const FormatException('A frase de recuperação deve conter exatamente 12 ou 24 palavras.');
    }

    final buffer = StringBuffer();
    for (final word in words) {
      final index = _wordIndexMap[word];
      if (index == null) {
        throw FormatException('A palavra "$word" não pertence ao vocabulário oficial BIP-39.');
      }
      buffer.write(index.toRadixString(2).padLeft(11, '0'));
    }

    final totalBits = buffer.toString();
    final entropyLengthBits = words.length == 12 ? 128 : 256;
    final checksumLengthBits = words.length == 12 ? 4 : 8;

    final entropyBits = totalBits.substring(0, entropyLengthBits);
    final checksumBits = totalBits.substring(entropyLengthBits);

    final entropyBytes = Uint8List(entropyLengthBits ~/ 8);
    for (var i = 0; i < entropyBytes.length; i++) {
      final byteChunk = entropyBits.substring(i * 8, (i + 1) * 8);
      entropyBytes[i] = int.parse(byteChunk, radix: 2);
    }

    // Valida integridade do checksum
    final hash = sha256.convert(entropyBytes).bytes;
    final expectedChecksum = hash[0].toRadixString(2).padLeft(8, '0').substring(0, checksumLengthBits);

    if (checksumBits != expectedChecksum) {
      throw const FormatException('Checksum da frase inválido. Verifique a ordem e digitação das palavras.');
    }

    return entropyBytes;
  }

  /// Valida se uma frase mnemônica é válida conforme a norma BIP-39.
  static bool validateMnemonic(String mnemonic) {
    try {
      mnemonicToEntropy(mnemonic);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deriva a chave privada hexadecimal de 32 bytes (64 caracteres) a partir da frase mnemônica.
  /// Compatível diretamente com Ethereum e Bitcoin Native SegWit no PrivateWallet.
  static String mnemonicToPrivateKeyHex(String mnemonic) {
    final entropy = mnemonicToEntropy(mnemonic);
    if (entropy.length == 32) {
      // 24 palavras: a própria entropia de 32 bytes representa o segredo criptográfico
      return entropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } else {
      // 12 palavras: deriva 32 bytes através do SHA-256 determinístico da entropia
      final hash = sha256.convert(entropy).bytes;
      return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
  }

  /// Converte uma chave privada hexadecimal existente de 32 bytes em uma frase de recuperação de 24 palavras.
  static String privateKeyHexToMnemonic(String hexKey) {
    final clean = hexKey.trim().replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(clean)) {
      throw const FormatException('A chave deve conter 64 caracteres hexadecimais.');
    }

    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return entropyToMnemonic(bytes);
  }
}
