import 'package:flutter_test/flutter_test.dart';
import 'package:private_wallet/services/bip39_service.dart';

void main() {
  group('BIP-39 Mnemonic Service', () {
    test('Official word list contains exactly 2048 words', () {
      expect(Bip39Service.totalWords, 2048);
    });

    test('Generates valid 12-word mnemonic phrase', () {
      final mnemonic = Bip39Service.generateMnemonic(words: 12);
      final words = mnemonic.split(' ');
      expect(words.length, 12);
      expect(Bip39Service.validateMnemonic(mnemonic), isTrue);

      final entropy = Bip39Service.mnemonicToEntropy(mnemonic);
      expect(entropy.length, 16);

      final privateKey = Bip39Service.mnemonicToPrivateKeyHex(mnemonic);
      expect(privateKey.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(privateKey), isTrue);
    });

    test('Generates valid 24-word mnemonic phrase', () {
      final mnemonic = Bip39Service.generateMnemonic(words: 24);
      final words = mnemonic.split(' ');
      expect(words.length, 24);
      expect(Bip39Service.validateMnemonic(mnemonic), isTrue);

      final entropy = Bip39Service.mnemonicToEntropy(mnemonic);
      expect(entropy.length, 32);

      final privateKey = Bip39Service.mnemonicToPrivateKeyHex(mnemonic);
      expect(privateKey.length, 64);
    });

    test('Round-trip hex key to 24-word mnemonic and back', () {
      const originalHex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final mnemonic = Bip39Service.privateKeyHexToMnemonic(originalHex);
      expect(mnemonic.split(' ').length, 24);
      expect(Bip39Service.validateMnemonic(mnemonic), isTrue);

      final derivedHex = Bip39Service.mnemonicToPrivateKeyHex(mnemonic);
      expect(derivedHex, originalHex);
    });

    test('Rejects invalid mnemonic phrases or invalid words', () {
      expect(Bip39Service.validateMnemonic('invalid word not in list'), isFalse);
      expect(Bip39Service.validateMnemonic('abandon ability able'), isFalse); // wrong length
    });
  });
}
