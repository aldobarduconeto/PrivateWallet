import '../models/networks.dart';
import 'bitcoin_codec.dart';
import 'ethereum_codec.dart';

/// Utilitários centralizados de formatação e parsing para Bitcoin e Ethereum,
/// eliminando redundâncias de código em formulários, cards e telas.
abstract final class CoinFormatter {
  /// Formata o valor para exibição.
  static String format(BigInt amount, String symbol, {String separator = ','}) {
    if (symbol.toUpperCase() == 'BTC') {
      return formatBtc(amount, separator: separator);
    }
    final eth = formatEth(amount);
    return separator == '.' ? eth.replaceAll(',', '.') : eth;
  }

  /// Interpreta a representação recebida.
  static BigInt parse(String text, String symbol) {
    if (symbol.toUpperCase() == 'BTC') {
      return parseBtc(text);
    }
    return parseEth(text);
  }

  /// Monta o link da transação no explorador da rede.
  static String explorerTxUrl(
    String hash, {
    required String symbol,
    Network? ethNetwork,
    BitcoinChain? btcChain,
  }) {
    if (symbol.toUpperCase() == 'BTC') {
      return '${(btcChain ?? BitcoinChain.testnet4).explorerUrl}/tx/$hash';
    }
    return '${(ethNetwork ?? Network.sepolia).explorerUrl}/tx/$hash';
  }

  /// Monta o link do endereço no explorador da rede.
  static String explorerAddressUrl(
    String address, {
    required String symbol,
    Network? ethNetwork,
    BitcoinChain? btcChain,
  }) {
    if (symbol.toUpperCase() == 'BTC') {
      return '${(btcChain ?? BitcoinChain.testnet4).explorerUrl}/address/$address';
    }
    return '${(ethNetwork ?? Network.sepolia).explorerUrl}/address/$address';
  }
}
