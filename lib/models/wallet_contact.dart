import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import 'networks.dart';
import 'wallet_account.dart';

/// Destinatário salvo na agenda local.
///
/// Contatos podem ser Multi-Moeda (com endereço ETH e BTC, @username e ID único)
/// ou vinculados a uma rede específica.
class WalletContact {
  /// Inicializa [WalletContact] com os dados recebidos.
  const WalletContact._(
    this.name,
    this.address,
    this.bitcoinChain, {
    this.username,
    this.uniqueId,
    this.ethAddress,
    this.btcAddress,
  });

  /// Inicializa [WalletContact] com os dados recebidos.
  factory WalletContact.parse(
    String name,
    String address, {
    BitcoinChain? bitcoin,
    String? username,
    String? uniqueId,
    String? ethAddress,
    String? btcAddress,
  }) {
    final label = name.trim();
    if (label.isEmpty || label.length > 40) {
      throw const FormatException('Use um nome de 1 a 40 caracteres.');
    }
    final normalized = bitcoin == null
        ? parseAddress(address).eip55With0x
        : parseBitcoinAddress(bitcoin, address).address;

    final sanitizedUsername = username != null && username.trim().isNotEmpty
        ? WalletAccount.sanitizeUsername(username)
        : null;

    final resolvedEth = ethAddress != null && ethAddress.isNotEmpty
        ? parseAddress(ethAddress).eip55With0x
        : (bitcoin == null ? normalized : null);

    final resolvedBtc = btcAddress != null && btcAddress.isNotEmpty
        ? parseBitcoinAddress(
            bitcoin ?? BitcoinChain.testnet4,
            btcAddress,
          ).address
        : (bitcoin != null ? normalized : null);

    return WalletContact._(
      label,
      normalized,
      bitcoin,
      username: sanitizedUsername,
      uniqueId: uniqueId?.trim(),
      ethAddress: resolvedEth,
      btcAddress: resolvedBtc,
    );
  }

  /// Inicializa [WalletContact] com os dados recebidos.
  factory WalletContact.multiCoin({
    required String name,
    required String ethAddress,
    required String btcAddress,
    BitcoinChain bitcoin = BitcoinChain.testnet4,
    String? username,
    String? uniqueId,
  }) {
    final label = name.trim();
    if (label.isEmpty || label.length > 40) {
      throw const FormatException('Use um nome de 1 a 40 caracteres.');
    }
    final normEth = parseAddress(ethAddress).eip55With0x;
    final normBtc = parseBitcoinAddress(bitcoin, btcAddress).address;
    return WalletContact._(
      label,
      normEth,
      bitcoin,
      username: username != null && username.isNotEmpty
          ? WalletAccount.sanitizeUsername(username)
          : null,
      uniqueId: uniqueId?.trim(),
      ethAddress: normEth,
      btcAddress: normBtc,
    );
  }

  /// Inicializa [WalletContact] com os dados recebidos.
  factory WalletContact.fromPayload(
    String payload, {
    BitcoinChain defaultBitcoin = BitcoinChain.testnet4,
  }) {
    final data = WalletAccount.parseContactPayload(payload);
    if (data == null) {
      throw const FormatException('Código ou link de contato inválido.');
    }

    final name = data['name'] ?? data['u'] ?? 'Amigo';
    final eth = data['eth'];
    final btc = data['btc'];
    final id = data['id'];
    final user = data['u'];

    if (eth != null && eth.isNotEmpty && btc != null && btc.isNotEmpty) {
      return WalletContact.multiCoin(
        name: name,
        ethAddress: eth,
        btcAddress: btc,
        bitcoin: defaultBitcoin,
        username: user,
        uniqueId: id,
      );
    } else if (btc != null && btc.isNotEmpty) {
      return WalletContact.parse(
        name,
        btc,
        bitcoin: defaultBitcoin,
        username: user,
        uniqueId: id,
      );
    } else if (eth != null && eth.isNotEmpty) {
      return WalletContact.parse(name, eth, username: user, uniqueId: id);
    }

    throw const FormatException(
      'Nenhum endereço encontrado no código de contato.',
    );
  }

  /// Reconstrói a instância a partir dos dados persistidos.
  factory WalletContact.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final address = json['address'];
    if (name is! String || address is! String) {
      throw const FormatException('Contato inválido.');
    }
    final bitcoin = switch (json['bitcoinChain']) {
      null => null,
      final String chain => BitcoinChain.values.byName(chain),
      _ => throw const FormatException('Rede do contato inválida.'),
    };

    final user = json['username'] as String?;
    final id = json['uniqueId'] as String?;
    final eth = json['ethAddress'] as String?;
    final btc = json['btcAddress'] as String?;

    return WalletContact.parse(
      name,
      address,
      bitcoin: bitcoin,
      username: user,
      uniqueId: id,
      ethAddress: eth,
      btcAddress: btc,
    );
  }

  final String name;
  final String address;
  final BitcoinChain? bitcoinChain;
  final String? username;
  final String? uniqueId;
  final String? ethAddress;
  final String? btcAddress;

  /// Indica a condição `isMultiCoin` usada em wallet contact.
  bool get isMultiCoin => ethAddress != null && btcAddress != null;

  /// Indica a condição `hasEth` usada em wallet contact.
  bool get hasEth => ethAddress != null || bitcoinChain == null;

  /// Indica a condição `hasBtc` usada em wallet contact.
  bool get hasBtc => btcAddress != null || bitcoinChain != null;

  /// Retorna o endereço Ethereum efetivo.
  String get effectiveEth =>
      ethAddress ?? (bitcoinChain == null ? address : '');

  /// Retorna o endereço Bitcoin efetivo.
  String get effectiveBtc =>
      btcAddress ?? (bitcoinChain != null ? address : '');

  /// Retorna por ativo em uso.
  String get symbol =>
      isMultiCoin ? 'ETH+BTC' : (bitcoinChain == null ? 'ETH' : 'BTC');

  /// Retorna o rótulo da rede em uso.
  String get networkLabel {
    if (isMultiCoin) return 'Ethereum e Bitcoin';
    return bitcoinChain?.label ?? 'Ethereum';
  }

  /// Indica se o contato pode receber da carteira com a rede informada.
  bool matches(BitcoinChain? chain) {
    if (isMultiCoin) return true;
    return bitcoinChain == chain;
  }

  /// Retorna o endereço correto para a rede alvo (ETH ou BTC).
  String addressFor(BitcoinChain? chain) {
    if (chain == null) {
      return effectiveEth.isNotEmpty ? effectiveEth : address;
    } else {
      return effectiveBtc.isNotEmpty ? effectiveBtc : address;
    }
  }

  /// Compara os destinos aplicando as regras do ativo e da rede.
  bool sameDestination(WalletContact other) {
    if (uniqueId != null &&
        other.uniqueId != null &&
        uniqueId == other.uniqueId) {
      return true;
    }
    return other.bitcoinChain == bitcoinChain &&
        other.address.toLowerCase() == address.toLowerCase();
  }

  /// Cria uma cópia com os campos informados e preserva os demais.
  WalletContact copyWith({
    String? name,
    String? address,
    BitcoinChain? bitcoinChain,
    String? username,
    String? uniqueId,
    String? ethAddress,
    String? btcAddress,
  }) {
    return WalletContact._(
      name ?? this.name,
      address ?? this.address,
      bitcoinChain ?? this.bitcoinChain,
      username: username ?? this.username,
      uniqueId: uniqueId ?? this.uniqueId,
      ethAddress: ethAddress ?? this.ethAddress,
      btcAddress: btcAddress ?? this.btcAddress,
    );
  }

  /// Converte a instância em um mapa para persistência.
  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    if (bitcoinChain != null) 'bitcoinChain': bitcoinChain!.name,
    if (username != null) 'username': username,
    if (uniqueId != null) 'uniqueId': uniqueId,
    if (ethAddress != null) 'ethAddress': ethAddress,
    if (btcAddress != null) 'btcAddress': btcAddress,
  };
}
