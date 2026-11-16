import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import '../../blockchain/bitcoin_codec.dart';
import '../../blockchain/ethereum_codec.dart';
import '../../models/networks.dart';

/// Serviço de segurança e conferência visual para evitar transferências erradas,
/// ataques de address poisoning (envenenamento de endereço) e clipboard hijackers.
class SecurityShieldService {
  /// Inicializa [SecurityShieldService] com os dados recebidos.
  const SecurityShieldService._();

  static const List<String> _shieldEmojis = [
    '🛡️',
    '💎',
    '🦁',
    '⚡',
    '🦅',
    '🚀',
    '🌊',
    '🍀',
    '🦉',
    '🪐',
    '👑',
    '🎯',
    '🔥',
    '🌈',
    '🦊',
    '🐉',
    '⚓',
    '☀️',
    '🌲',
    '🌸',
    '🎸',
    '🔑',
    '🏆',
    '🧭',
    '🧩',
    '🔔',
    '🍇',
    '🍒',
    '🌙',
    '⭐',
    '💡',
    '🎨',
  ];

  static const List<Color> _shieldColors = [
    Color(0xFF3B82F6), // Azul
    Color(0xFF10B981), // Verde Esmeralda
    Color(0xFFF59E0B), // Âmbar / Ouro
    Color(0xFF8B5CF6), // Roxo
    Color(0xFFEC4899), // Rosa
    Color(0xFF06B6D4), // Ciano
    Color(0xFFEF4444), // Vermelho Coral
    Color(0xFF14B8A6), // Menta
  ];

  /// Gera uma sequência determinística de 4 emojis imutáveis a partir do endereço.
  /// Ambos o pagador e o recebedor podem conferir esses 4 emojis para certificar
  /// que a chave pública não sofreu alteração nem foi substituída por malware.
  static String visualEmojis(String address) {
    final clean = address.trim().toLowerCase();
    if (clean.isEmpty) return '🛡️ ❓ ❓ ❓';

    final hash = keccak256(Uint8List.fromList(utf8.encode(clean)));
    final e1 = _shieldEmojis[hash[0] % _shieldEmojis.length];
    final e2 = _shieldEmojis[hash[1] % _shieldEmojis.length];
    final e3 = _shieldEmojis[hash[2] % _shieldEmojis.length];
    final e4 = _shieldEmojis[hash[3] % _shieldEmojis.length];

    return '$e1 $e2 $e3 $e4';
  }

  /// Retorna a cor de identificação única do endereço.
  static Color shieldColor(String address) {
    final clean = address.trim().toLowerCase();
    if (clean.isEmpty) return _shieldColors.first;
    final hash = keccak256(Uint8List.fromList(utf8.encode(clean)));
    return _shieldColors[hash[4] % _shieldColors.length];
  }

  /// Valida formalmente a estrutura do endereço conforme a rede.
  static bool isValidAddress(String address, {BitcoinChain? bitcoin}) {
    try {
      final clean = address.trim();
      if (clean.isEmpty) return false;
      if (bitcoin != null) {
        parseBitcoinAddress(bitcoin, clean);
        return true;
      } else {
        parseAddress(clean);
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Detecta potencial golpe de "Address Poisoning":
  /// Golpistas criam endereços com os mesmos primeiros e últimos caracteres
  /// de um endereço frequente do usuário para induzi-lo ao erro.
  static bool isPoisoningRisk({
    required String targetAddress,
    required List<String> knownAddresses,
  }) {
    final target = targetAddress.trim().toLowerCase();
    if (target.length < 12) return false;

    final targetHead = target.substring(0, 5);
    final targetTail = target.substring(target.length - 4);

    for (final known in knownAddresses) {
      final k = known.trim().toLowerCase();
      if (k == target) continue; // É exatamente o mesmo endereço legítimo

      if (k.length >= 12) {
        final kHead = k.substring(0, 5);
        final kTail = k.substring(k.length - 4);

        if (targetHead == kHead && targetTail == kTail) {
          // O endereço tem início e fim idênticos mas o meio é diferente!
          return true;
        }
      }
    }
    return false;
  }
}
