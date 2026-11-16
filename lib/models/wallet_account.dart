import 'dart:convert';
import 'dart:math';

import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../blockchain/multi_coin_codec.dart';
import 'networks.dart';

final _curveOrder = BigInt.parse(
  'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
  radix: 16,
);

/// Representa uma carteira no aplicativo.
/// Suporta contas unificadas Multi-Moeda (ETH + BTC) ou contas de ativo único.
/// Exige um nome de usuário (@username) associado à conta.
class WalletAccount {
  /// Normaliza o nome de usuário para o formato aceito pela carteira.
  static String sanitizeUsername(String input) {
    var clean = input.trim();
    if (clean.startsWith('@')) clean = clean.substring(1);
    clean = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (clean.length < 3) {
      clean = clean.padRight(3, '0');
    }
    if (clean.length > 25) {
      clean = clean.substring(0, 25);
    }
    return '@$clean';
  }

  /// Gera um identificador único exclusivo e determinístico para a carteira (ex: PW-7F4A-C9B2).
  static String generateUniqueId(String publicAddress, [String? btcAddress]) {
    final seed =
        '${publicAddress.toLowerCase()}_${(btcAddress ?? '').toLowerCase()}';
    final hash = bytesToHex(keccak256(utf8.encode(seed)));
    final part1 = hash.substring(0, 4).toUpperCase();
    final part2 = hash.substring(4, 8).toUpperCase();
    return 'PW-$part1-$part2';
  }

  /// Faz o parsing de um payload de contato compartilhado (URI pw://contact ou JSON).
  static Map<String, String>? parseContactPayload(String payload) {
    try {
      final trimmed = payload.trim();
      if (trimmed.startsWith('pw://contact')) {
        final uri = Uri.parse(trimmed);
        return uri.queryParameters;
      }
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return null;
  }

  /// Identificador exclusivo desta carteira no Private Wallet.
  String get uniqueId => generateUniqueId(publicAddress, btcAddress);

  /// Gera a URI padronizada para compartilhar o cartão de contato com outros usuários.
  String get contactSharePayload {
    final eth = ethAddress ?? (bitcoinChain == null ? publicAddress : '');
    final btc = btcAddress ?? (bitcoinChain != null ? publicAddress : '');
    final uri = Uri(
      scheme: 'pw',
      host: 'contact',
      queryParameters: {
        'id': uniqueId,
        'name': name,
        'u': username,
        if (eth.isNotEmpty) 'eth': eth,
        if (btc.isNotEmpty) 'btc': btc,
      },
    );
    return uri.toString();
  }

  // Construtor para carteira somente Ethereum
  /// Inicializa [WalletAccount] com os dados recebidos.
  WalletAccount(
    this.name,
    EthereumAddress address, {
    String? username,
    this.secret,
  }) : username = username != null && username.isNotEmpty
           ? sanitizeUsername(username)
           : sanitizeUsername(name),
       publicAddress = address.eip55With0x,
       bitcoinChain = null,
       ethAddress = address.eip55With0x,
       btcAddress = null,
       btcSecret = null,
       isMultiCoin = false,
       activeAsset = 'ETH';

  // Construtor para carteira somente Bitcoin
  /// Inicializa [WalletAccount] com os dados recebidos.
  WalletAccount._bitcoin(
    this.name,
    this.publicAddress,
    this.bitcoinChain, {
    String? username,
    this.secret,
  }) : username = username != null && username.isNotEmpty
           ? sanitizeUsername(username)
           : sanitizeUsername(name),
       ethAddress = null,
       btcAddress = publicAddress,
       btcSecret = secret,
       isMultiCoin = false,
       activeAsset = 'BTC';

  // Construtor completo unificado Multi-Moeda
  /// Inicializa [WalletAccount] com os dados recebidos.
  WalletAccount.multiCoin({
    required this.name,
    String? username,
    required this.ethAddress,
    required this.btcAddress,
    required this.bitcoinChain,
    this.secret,
    this.btcSecret,
    this.activeAsset = 'ETH',
  }) : username = username != null && username.isNotEmpty
           ? sanitizeUsername(username)
           : sanitizeUsername(name),
       publicAddress = ethAddress ?? '',
       isMultiCoin = true;

  /// Cria uma carteira de observação usando somente o endereço informado.
  factory WalletAccount.watch(
    String name,
    String address, {
    String? username,
    BitcoinChain? bitcoin,
  }) {
    if (bitcoin != null) {
      return WalletAccount._bitcoin(
        name,
        parseBitcoinAddress(bitcoin, address).address,
        bitcoin,
        username: username,
      );
    }
    return WalletAccount(name, parseAddress(address), username: username);
  }

  /// Cria uma carteira de observação com endereços de BTC e ETH.
  factory WalletAccount.watchMultiCoin(
    String name, {
    String? username,
    required String ethAddress,
    required String btcAddress,
    BitcoinChain bitcoin = BitcoinChain.testnet4,
  }) {
    return WalletAccount.multiCoin(
      name: name,
      username: username,
      ethAddress: parseAddress(ethAddress).eip55With0x,
      btcAddress: parseBitcoinAddress(bitcoin, btcAddress).address,
      bitcoinChain: bitcoin,
    );
  }

  /// Inicializa [WalletAccount] com os dados recebidos.
  factory WalletAccount.create(
    String name, {
    String? username,
    BitcoinChain? bitcoin,
  }) {
    if (bitcoin != null) {
      return WalletAccount.import(
        name,
        newBitcoinKey(bitcoin),
        username: username,
        bitcoin: bitcoin,
      );
    }
    final key = EthPrivateKey.createRandom(Random.secure());
    return WalletAccount(
      name,
      key.address,
      username: username,
      secret: key.privateKeyInt.toRadixString(16).padLeft(64, '0'),
    );
  }

  /// Cria uma carteira Multi-Coin que suporta Ethereum e Bitcoin simultaneamente
  /// com derivação de par de chaves e endereços a partir da mesma semente.
  factory WalletAccount.createMultiCoin(
    String name, {
    String? username,
    BitcoinChain bitcoin = BitcoinChain.testnet4,
  }) {
    final keys = MultiCoinKeys.generate(bitcoin: bitcoin);
    return WalletAccount.multiCoin(
      name: name,
      username: username,
      ethAddress: keys.ethAddress,
      btcAddress: keys.btcAddress,
      bitcoinChain: bitcoin,
      secret: keys.hexSecret,
      btcSecret: keys.btcWif,
    );
  }

  /// Reconstrói uma carteira a partir do material de recuperação informado.
  factory WalletAccount.import(
    String name,
    String input, {
    String? username,
    BitcoinChain? bitcoin,
  }) {
    if (bitcoin != null) {
      final key = importBitcoinKey(bitcoin, input);
      return WalletAccount._bitcoin(
        name,
        bitcoinAddressForKey(bitcoin, key),
        bitcoin,
        username: username,
        secret: input.trim(),
      );
    }
    final secret = input.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(secret)) {
      throw const FormatException(
        'A chave privada deve ter 64 caracteres hexadecimais.',
      );
    }
    final value = BigInt.parse(secret, radix: 16);
    if (value == BigInt.zero || value >= _curveOrder) {
      throw const FormatException('A chave privada é inválida.');
    }
    return WalletAccount(
      name,
      EthPrivateKey.fromHex(secret).address,
      username: username,
      secret: secret,
    );
  }

  /// Importa uma carteira Multi-Coin a partir de uma chave privada hex de 32 bytes
  factory WalletAccount.importMultiCoin(
    String name,
    String hexInput, {
    String? username,
    BitcoinChain bitcoin = BitcoinChain.testnet4,
  }) {
    final keys = MultiCoinKeys.fromHexSecret(hexInput, bitcoin: bitcoin);
    return WalletAccount.multiCoin(
      name: name,
      username: username,
      ethAddress: keys.ethAddress,
      btcAddress: keys.btcAddress,
      bitcoinChain: bitcoin,
      secret: keys.hexSecret,
      btcSecret: keys.btcWif,
    );
  }

  final String name;
  final String username;
  final String publicAddress;
  final BitcoinChain? bitcoinChain;
  final String? ethAddress;
  final String? btcAddress;
  final String? secret;
  final String? btcSecret;
  final bool isMultiCoin;
  final String activeAsset; // 'ETH' ou 'BTC'

  /// Indica se a carteira possui material de assinatura.
  bool get canSign => secret != null || btcSecret != null;

  /// Retorna o endereço em uso.
  EthereumAddress get address => parseAddress(
    ethAddress ??
        (bitcoinChain == null
            ? publicAddress
            : '0x0000000000000000000000000000000000000000'),
  );

  /// Retorna por ativo em uso.
  String get symbol =>
      isMultiCoin ? activeAsset : (bitcoinChain == null ? 'ETH' : 'BTC');

  /// Retorna `currentAddress` para consulta em conta.
  String get currentAddress => isMultiCoin
      ? (activeAsset == 'BTC'
            ? (btcAddress ?? publicAddress)
            : (ethAddress ?? publicAddress))
      : publicAddress;

  /// Cria uma cópia com os campos informados e preserva os demais.
  WalletAccount copyWith({
    String? name,
    String? username,
    BitcoinChain? bitcoinChain,
    String? secret,
    String? btcSecret,
    String? activeAsset,
  }) {
    final nextName = name ?? this.name;
    final nextUsername = username ?? this.username;

    if (isMultiCoin) {
      return WalletAccount.multiCoin(
        name: nextName,
        username: nextUsername,
        ethAddress: ethAddress!,
        btcAddress: btcAddress!,
        bitcoinChain: bitcoinChain ?? this.bitcoinChain!,
        secret: secret ?? this.secret,
        btcSecret: btcSecret ?? this.btcSecret,
        activeAsset: activeAsset ?? this.activeAsset,
      );
    }
    if (this.bitcoinChain != null) {
      return WalletAccount._bitcoin(
        nextName,
        publicAddress,
        bitcoinChain ?? this.bitcoinChain,
        username: nextUsername,
        secret: secret ?? this.secret,
      );
    }
    return WalletAccount(
      nextName,
      address,
      username: nextUsername,
      secret: secret ?? this.secret,
    );
  }

  /// Retorna uma cópia desta conta em modo Espelho (Watch-Only),
  /// removendo todas as chaves privadas para monitoramento seguro.
  WalletAccount toMirror() {
    if (isMultiCoin) {
      return WalletAccount.multiCoin(
        name: name,
        username: username,
        ethAddress: ethAddress,
        btcAddress: btcAddress,
        bitcoinChain: bitcoinChain,
        secret: null,
        btcSecret: null,
        activeAsset: activeAsset,
      );
    }
    if (bitcoinChain != null) {
      return WalletAccount._bitcoin(
        name,
        publicAddress,
        bitcoinChain,
        username: username,
        secret: null,
      );
    }
    return WalletAccount(name, address, username: username, secret: null);
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'address': publicAddress,
    if (bitcoinChain != null) 'bitcoinChain': bitcoinChain!.name,
    if (secret != null) 'secret': secret,
    if (isMultiCoin) 'isMultiCoin': true,
    if (ethAddress != null) 'ethAddress': ethAddress,
    if (btcAddress != null) 'btcAddress': btcAddress,
    if (btcSecret != null) 'btcSecret': btcSecret,
    'activeAsset': activeAsset,
  };

  /// Reconstrói a instância a partir dos dados persistidos.
  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final address = json['address'];
    final secret = json['secret'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 40 ||
        address is! String ||
        (secret != null && secret is! String)) {
      throw const FormatException('Dados da carteira inválidos.');
    }

    final rawUsername = json['username'] as String?;
    final username = rawUsername != null && rawUsername.trim().isNotEmpty
        ? sanitizeUsername(rawUsername)
        : sanitizeUsername(name);

    final bitcoin = switch (json['bitcoinChain']) {
      null => null,
      'testnet4' => BitcoinChain.testnet4,
      'mainnet' => BitcoinChain.mainnet,
      _ => throw const FormatException('Rede Bitcoin inválida.'),
    };

    final isMulti = json['isMultiCoin'] == true;
    if (isMulti) {
      final ethAddr = json['ethAddress'] as String? ?? address;
      final btcAddr = json['btcAddress'] as String?;
      final btcSec = json['btcSecret'] as String?;
      final active = json['activeAsset'] as String? ?? 'ETH';

      if (btcAddr != null && bitcoin != null) {
        return WalletAccount.multiCoin(
          name: name,
          username: username,
          ethAddress: ethAddr,
          btcAddress: btcAddr,
          bitcoinChain: bitcoin,
          secret: secret,
          btcSecret: btcSec,
          activeAsset: active,
        );
      }
    }

    final watched = WalletAccount.watch(
      name,
      address,
      username: username,
      bitcoin: bitcoin,
    );
    if (secret == null) return watched;
    final restored = WalletAccount.import(
      name,
      secret,
      username: username,
      bitcoin: bitcoin,
    );
    if (restored.publicAddress != watched.publicAddress) {
      throw const FormatException(
        'A chave e o endereço da carteira são incompatíveis.',
      );
    }
    return restored;
  }
}
