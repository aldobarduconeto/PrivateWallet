import 'dart:math';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/wallet_controller.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import 'crypto_finance_service.dart';

/// Unidade de exibição e cálculo para operações com Bitcoin.
enum BitcoinUnit {
  btc('BTC', 8),
  satoshis('Satoshis (sats)', 0);

  const BitcoinUnit(this.label, this.decimals);
  final String label;
  final int decimals;
}

/// Orçamento e cotação de uma operação de troca (Swap) entre Bitcoin e Ethereum.
class SwapQuote {
  const SwapQuote({
    required this.fromSymbol,
    required this.toSymbol,
    required this.fromAmount,
    required this.toAmount,
    required this.protocolFee,
    required this.minReceived,
    required this.rate,
    required this.inverseRate,
    required this.slippagePercent,
    required this.btcUnit,
  });

  final String fromSymbol; // 'BTC' ou 'ETH'
  final String toSymbol; // 'ETH' ou 'BTC'
  final BigInt fromAmount; // Satoshis (se BTC) ou Wei (se ETH)
  final BigInt toAmount; // Wei (se ETH) ou Satoshis (se BTC)
  final BigInt protocolFee; // Taxa de protocolo na moeda de saída
  final BigInt minReceived; // Mínimo garantido pós-slippage
  final double rate; // 1 BTC em ETH (ou 1 ETH em BTC)
  final double inverseRate;
  final double slippagePercent;
  final BitcoinUnit btcUnit;

  /// Retorna o valor de entrada formatado de acordo com a unidade configurada.
  String get formattedFrom {
    if (fromSymbol == 'BTC') {
      if (btcUnit == BitcoinUnit.satoshis) {
        return '${_formatWithThousands(fromAmount.toInt())} sats';
      }
      return '${formatBtc(fromAmount)} BTC';
    }
    return '${formatEth(fromAmount)} ETH';
  }

  /// Retorna a quantidade de satoshis se for Bitcoin, ou texto explicativo.
  String? get fromSatsDetail {
    if (fromSymbol == 'BTC') {
      if (btcUnit == BitcoinUnit.satoshis) {
        return '≈ ${formatBtc(fromAmount)} BTC';
      }
      return '≈ ${_formatWithThousands(fromAmount.toInt())} satoshis';
    }
    return null;
  }

  /// Retorna o valor de saída formatado.
  String get formattedTo {
    if (toSymbol == 'BTC') {
      if (btcUnit == BitcoinUnit.satoshis) {
        return '${_formatWithThousands(toAmount.toInt())} sats';
      }
      return '${formatBtc(toAmount)} BTC';
    }
    return '${formatEth(toAmount)} ETH';
  }

  /// Retorna detalhes adicionais do valor de saída (ex: satoshis quando BTC).
  String? get toSatsDetail {
    if (toSymbol == 'BTC') {
      if (btcUnit == BitcoinUnit.satoshis) {
        return '≈ ${formatBtc(toAmount)} BTC';
      }
      return '≈ ${_formatWithThousands(toAmount.toInt())} satoshis';
    }
    return null;
  }

  /// Retorna a taxa de protocolo formatada.
  String get formattedFee {
    if (toSymbol == 'BTC') {
      return btcUnit == BitcoinUnit.satoshis
          ? '${_formatWithThousands(protocolFee.toInt())} sats'
          : '${formatBtc(protocolFee)} BTC';
    }
    return '${formatEth(protocolFee)} ETH';
  }

  /// Retorna o mínimo recebido garantido formatado.
  String get formattedMinReceived {
    if (toSymbol == 'BTC') {
      return btcUnit == BitcoinUnit.satoshis
          ? '${_formatWithThousands(minReceived.toInt())} sats'
          : '${formatBtc(minReceived)} BTC';
    }
    return '${formatEth(minReceived)} ETH';
  }

  static String _formatWithThousands(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }
}

/// Resultado oficial da execução de um Swap.
class SwapResult {
  const SwapResult({
    required this.txHash,
    required this.quote,
    required this.fromAddress,
    required this.toAddress,
    required this.timestamp,
    required this.activity,
  });

  final String txHash;
  final SwapQuote quote;
  final String fromAddress;
  final String toAddress;
  final DateTime timestamp;
  final WalletActivity activity;
}

/// Serviço de orquestração de Troca de Moedas (Cross-Chain Swap BTC ⇄ ETH).
class CryptoSwapService {
  const CryptoSwapService();

  /// Taxa do protocolo de liquidez de 0,25%.
  static const double protocolFeePercent = 0.0025;

  /// Cotações de referência de mercado.
  static double get btcPriceUsd => CryptoFinanceService.btcPriceUsd;
  static double get ethPriceUsd => CryptoFinanceService.ethPriceUsd;
  static double get btcPriceBrl => CryptoFinanceService.btcPriceBrl;
  static double get ethPriceBrl => CryptoFinanceService.ethPriceBrl;

  /// Taxa de câmbio: quantos ETH vale 1 BTC.
  static double get btcToEthRate => btcPriceUsd / ethPriceUsd;

  /// Taxa inversa: quantos BTC vale 1 ETH.
  static double get ethToBtcRate => ethPriceUsd / btcPriceUsd;

  /// Quantos satoshis vale 1 ETH.
  static BigInt get ethToSatoshis =>
      BigInt.from((ethToBtcRate * 100000000).round());

  /// Gera a cotação calculada para a troca entre BTC e ETH ou ETH e BTC.
  static SwapQuote calculateQuote({
    required String fromSymbol,
    required String toSymbol,
    required double inputAmount,
    BitcoinUnit btcUnit = BitcoinUnit.btc,
    double slippagePercent = 0.5,
  }) {
    if (inputAmount <= 0) {
      throw const FormatException('Informe um valor maior que zero para troca.');
    }

    final isBtcToEth = fromSymbol == 'BTC';
    final rate = isBtcToEth ? btcToEthRate : ethToBtcRate;
    final inverseRate = isBtcToEth ? ethToBtcRate : btcToEthRate;

    BigInt fromAmount;
    BigInt toAmount;
    BigInt protocolFee;
    BigInt minReceived;

    if (isBtcToEth) {
      // De Bitcoin (Satoshis ou BTC) para Ethereum (Wei)
      if (btcUnit == BitcoinUnit.satoshis) {
        fromAmount = BigInt.from(inputAmount.round());
      } else {
        fromAmount = BigInt.from((inputAmount * 1e8).round());
      }

      final grossEth = (fromAmount.toDouble() / 1e8) * btcToEthRate;
      final feeEth = grossEth * protocolFeePercent;
      final netEth = grossEth - feeEth;

      toAmount = BigInt.from((netEth * 1e18).round());
      protocolFee = BigInt.from((feeEth * 1e18).round());
      final minEth = netEth * (1.0 - (slippagePercent / 100.0));
      minReceived = BigInt.from((minEth * 1e18).round());
    } else {
      // De Ethereum (ETH / Wei) para Bitcoin (Satoshis ou BTC)
      fromAmount = BigInt.from((inputAmount * 1e18).round());

      final grossBtc = (fromAmount.toDouble() / 1e18) * ethToBtcRate;
      final feeBtc = grossBtc * protocolFeePercent;
      final netBtc = grossBtc - feeBtc;

      toAmount = BigInt.from((netBtc * 1e8).round());
      protocolFee = BigInt.from((feeBtc * 1e8).round());
      final minBtc = netBtc * (1.0 - (slippagePercent / 100.0));
      minReceived = BigInt.from((minBtc * 1e8).round());
    }

    return SwapQuote(
      fromSymbol: fromSymbol,
      toSymbol: toSymbol,
      fromAmount: fromAmount,
      toAmount: toAmount,
      protocolFee: protocolFee,
      minReceived: minReceived,
      rate: rate,
      inverseRate: inverseRate,
      slippagePercent: slippagePercent,
      btcUnit: btcUnit,
    );
  }

  /// Executa o swap de moedas com registro contábil e atualização dos saldos.
  static Future<SwapResult> executeSwap({
    required WalletController controller,
    required WalletAccount account,
    required Network network,
    required SwapQuote quote,
    required String destinationAddress,
    BigInt? currentSourceBalance,
    BigInt? currentTargetBalance,
  }) async {
    final fromSymbol = quote.fromSymbol;
    final toSymbol = quote.toSymbol;

    final srcBalance =
        currentSourceBalance ??
        controller.lastKnownBalanceForSymbol(fromSymbol) ??
        BigInt.zero;
    final tgtBalance =
        currentTargetBalance ??
        controller.lastKnownBalanceForSymbol(toSymbol) ??
        BigInt.zero;

    if (srcBalance < quote.fromAmount) {
      throw FormatException(
        'Saldo insuficiente de $fromSymbol para realizar a troca. '
        'Necessário: ${quote.formattedFrom}. Disponível: ${fromSymbol == "BTC" ? formatBtc(srcBalance) : formatEth(srcBalance)} $fromSymbol.',
      );
    }

    // Calcula novos saldos locais
    final newSourceBalance = srcBalance - quote.fromAmount;
    final newTargetBalance = tgtBalance + quote.toAmount;

    // Gera Hash criptográfico determinístico da transação de swap
    final rnd = Random.secure();
    final bytes = List<int>.generate(28, (_) => rnd.nextInt(256));
    final randomHex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final txHash = '0xswap$randomHex';

    final isBtc = fromSymbol == 'BTC';
    final fromAddress = isBtc
        ? (account.btcAddress ?? account.publicAddress)
        : (account.ethAddress ?? account.publicAddress);
    final netId = isBtc
        ? (account.bitcoinChain?.name ?? 'testnet4')
        : network.name;

    final now = DateTime.now();
    final swapLabel = 'Troca (Swap $fromSymbol ➔ $toSymbol)';
    final detail =
        'Trocou ${quote.formattedFrom} por ${quote.formattedTo} (Taxa: ${quote.formattedFee})';

    final activity = WalletActivity(
      hash: txHash,
      networkId: netId,
      bitcoin: isBtc,
      sender: fromAddress,
      recipient: destinationAddress,
      amount: quote.fromAmount,
      fee: quote.protocolFee,
      created: now,
      paymentType: swapLabel,
      purchaseName: detail,
    );

    // Registra a atividade no histórico do usuário
    await controller.recordActivity(activity);

    // Atualiza imediatamente os saldos em cache no controller
    controller.setCachedBalanceForSymbol(fromSymbol, newSourceBalance);
    controller.setCachedBalanceForSymbol(toSymbol, newTargetBalance);

    return SwapResult(
      txHash: txHash,
      quote: quote,
      fromAddress: fromAddress,
      toAddress: destinationAddress,
      timestamp: now,
      activity: activity,
    );
  }
}
