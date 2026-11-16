import 'dart:math';

import '../models/fiat_currency.dart';

class CryptoFinanceService {
  /// Inicializa [CryptoFinanceService] com os dados recebidos.
  const CryptoFinanceService();

  // Cotações base de referência de mercado (BRL e USD)
  static const double btcPriceBrl = 385000.0;
  static const double btcPriceUsd = 68500.0;
  static const double ethPriceBrl = 16800.0;
  static const double ethPriceUsd = 2980.0;

  static const double satsPerBtc = 100000000.0;
  static final double weiPerEth = pow(10, 18).toDouble();

  /// Converte Satoshis para BRL
  double satsToBrl(BigInt sats) => (sats.toDouble() / satsPerBtc) * btcPriceBrl;

  /// Converte Satoshis para USD
  double satsToUsd(BigInt sats) => (sats.toDouble() / satsPerBtc) * btcPriceUsd;

  /// Converte Wei para BRL
  double weiToBrl(BigInt wei) => (wei.toDouble() / weiPerEth) * ethPriceBrl;

  /// Converte Wei para USD
  double weiToUsd(BigInt wei) => (wei.toDouble() / weiPerEth) * ethPriceUsd;

  /// Converte o saldo em unidades mínimas para a moeda escolhida.
  double valueIn(
    BigInt amount,
    String symbol,
    FiatCurrency currency,
    double rate,
  ) {
    final isBtc = symbol == 'BTC';
    if (currency.code == 'BRL') {
      return isBtc ? satsToBrl(amount) : weiToBrl(amount);
    }
    return (isBtc ? satsToUsd(amount) : weiToUsd(amount)) * rate;
  }

  /// Converte Reais (BRL) para Satoshis
  BigInt brlToSats(double brl) {
    if (brl <= 0) return BigInt.zero;
    final btc = brl / btcPriceBrl;
    return BigInt.from((btc * satsPerBtc).round());
  }

  /// Converte Reais (BRL) para Wei
  BigInt brlToWei(double brl) {
    if (brl <= 0) return BigInt.zero;
    final eth = brl / ethPriceBrl;
    return BigInt.from((eth * 1e9).round()) * BigInt.from(1000000000);
  }

  /// Converte valor cripto para BRL e USD
  static ({double brl, double usd}) convertCrypto({
    required String symbol,
    required double amount,
  }) {
    final isBtc = symbol.toUpperCase() == 'BTC';
    if (isBtc) {
      return (brl: amount * btcPriceBrl, usd: amount * btcPriceUsd);
    } else {
      return (brl: amount * ethPriceBrl, usd: amount * ethPriceUsd);
    }
  }

  /// Simula estratégia DCA (Dollar Cost Averaging / Aporte Periódico)
  DcaResult simulateDca({
    String? symbol,
    double? periodContributionFiat,
    int? totalPeriods,
    double annualExpectedReturnRate = 0.15,
    double? periodicAmountBrl,
    int? months,
    int? frequencyDays, // 7 = semanal, 15 = quinzenal, 30 = mensal
    bool? isBitcoin,
  }) {
    final effectiveIsBtc = isBitcoin ?? (symbol?.toUpperCase() != 'ETH');
    final effectivePeriodicAmount =
        periodContributionFiat ?? periodicAmountBrl ?? 0.0;
    final int effectiveTotalAportes =
        totalPeriods ?? ((months ?? 1) * 30 / (frequencyDays ?? 30)).floor();
    final totalInvestedBrl = effectiveTotalAportes * effectivePeriodicAmount;

    final unitPrice = effectiveIsBtc ? btcPriceBrl : ethPriceBrl;
    var accumulatedCoins = 0.0;

    // Simulação com variação histórica estimada de mercado (+/- 15% de volatilidade ao longo do período)
    final random = Random(42);
    for (var i = 0; i < effectiveTotalAportes; i++) {
      final variation = 1.0 + (random.nextDouble() * 0.3 - 0.12);
      final priceAtAporte = unitPrice * variation;
      accumulatedCoins += priceAtAporte > 0
          ? (effectivePeriodicAmount / priceAtAporte)
          : 0.0;
    }

    final currentEstimatedValueBrl = accumulatedCoins * unitPrice;
    final averagePrice = effectiveTotalAportes > 0 && accumulatedCoins > 0
        ? (totalInvestedBrl / accumulatedCoins)
        : 0.0;
    final profitPercent = totalInvestedBrl > 0
        ? ((currentEstimatedValueBrl - totalInvestedBrl) / totalInvestedBrl) *
              100
        : 0.0;

    return DcaResult(
      totalAportes: effectiveTotalAportes,
      totalInvestedBrl: totalInvestedBrl,
      accumulatedCoins: accumulatedCoins,
      averagePriceBrl: averagePrice,
      currentValueBrl: currentEstimatedValueBrl,
      profitPercent: profitPercent,
      symbol: effectiveIsBtc ? 'BTC' : 'ETH',
    );
  }
}

class DcaResult {
  /// Inicializa [DcaResult] com os dados recebidos.
  const DcaResult({
    required this.totalAportes,
    required this.totalInvestedBrl,
    required this.accumulatedCoins,
    required this.averagePriceBrl,
    required this.currentValueBrl,
    required this.profitPercent,
    required this.symbol,
  });

  final int totalAportes;
  final double totalInvestedBrl;
  final double accumulatedCoins;
  final double averagePriceBrl;
  final double currentValueBrl;
  final double profitPercent;
  final String symbol;

  /// Retorna `totalCryptoAccumulated` para consulta em crypto finance.
  double get totalCryptoAccumulated => accumulatedCoins;

  /// Retorna `totalFiatInvested` para consulta em crypto finance.
  double get totalFiatInvested => totalInvestedBrl;

  /// Retorna `estimatedFiatPortfolioValue` para consulta em crypto finance.
  double get estimatedFiatPortfolioValue => currentValueBrl;
}
