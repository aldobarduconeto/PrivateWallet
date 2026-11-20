import 'package:flutter_test/flutter_test.dart';
import 'package:private_wallet/controllers/wallet_controller.dart';
import 'package:private_wallet/models/networks.dart';
import 'package:private_wallet/models/wallet_account.dart';
import 'package:private_wallet/services/crypto_swap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CryptoSwapService Calculations', () {
    test('Calculates Bitcoin to Ethereum quote in BTC', () {
      final quote = CryptoSwapService.calculateQuote(
        fromSymbol: 'BTC',
        toSymbol: 'ETH',
        inputAmount: 1.0,
        btcUnit: BitcoinUnit.btc,
        slippagePercent: 0.5,
      );

      expect(quote.fromSymbol, 'BTC');
      expect(quote.toSymbol, 'ETH');
      expect(quote.fromAmount, BigInt.from(100000000)); // 1 BTC = 10^8 sats
      expect(quote.toAmount > BigInt.zero, isTrue);
      expect(quote.protocolFee > BigInt.zero, isTrue);
      expect(quote.minReceived < quote.toAmount, isTrue);
      expect(quote.rate, closeTo(CryptoSwapService.btcToEthRate, 0.001));
    });

    test('Calculates Bitcoin to Ethereum quote in Satoshis (sats)', () {
      final quote = CryptoSwapService.calculateQuote(
        fromSymbol: 'BTC',
        toSymbol: 'ETH',
        inputAmount: 100000000, // 100 milhões de satoshis = 1 BTC
        btcUnit: BitcoinUnit.satoshis,
        slippagePercent: 0.5,
      );

      expect(quote.fromSymbol, 'BTC');
      expect(quote.toSymbol, 'ETH');
      expect(quote.fromAmount, BigInt.from(100000000));
      expect(quote.toAmount > BigInt.zero, isTrue);
    });

    test('Calculates Ethereum to Bitcoin quote (returning sats and btc)', () {
      final quote = CryptoSwapService.calculateQuote(
        fromSymbol: 'ETH',
        toSymbol: 'BTC',
        inputAmount: 1.0, // 1 ETH
        btcUnit: BitcoinUnit.satoshis,
        slippagePercent: 0.5,
      );

      expect(quote.fromSymbol, 'ETH');
      expect(quote.toSymbol, 'BTC');
      expect(quote.fromAmount, BigInt.from(10).pow(18)); // 1 ETH = 10^18 wei
      expect(quote.toAmount > BigInt.zero, isTrue);
      // 1 ETH deve render cerca de 4.4 milhões de satoshis
      expect(quote.toAmount, greaterThan(BigInt.from(3000000)));
      expect(quote.toAmount, lessThan(BigInt.from(6000000)));
    });

    test('Zero or negative amount throws FormatException', () {
      expect(
        () => CryptoSwapService.calculateQuote(
          fromSymbol: 'BTC',
          toSymbol: 'ETH',
          inputAmount: 0,
        ),
        throwsFormatException,
      );

      expect(
        () => CryptoSwapService.calculateQuote(
          fromSymbol: 'ETH',
          toSymbol: 'BTC',
          inputAmount: -1.5,
        ),
        throwsFormatException,
      );
    });
  });
}
