import 'package:intl/intl.dart';

class FiatCurrency {
  /// Inicializa [FiatCurrency] com os dados recebidos.
  const FiatCurrency(this.code);

  static const brl = FiatCurrency('BRL');
  // Códigos retornados pela ExchangeRate-API, disponíveis também offline.
  static final supportedCodes = List<String>.unmodifiable(
    _catalog.trim().split(RegExp(r'\s+')),
  );

  static const _catalog = '''
    AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT
    BGN BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD CAD
    CDF CHF CLF CLP CNH CNY COP CRC CUP CVE CZK DJF DKK
    DOP DZD EGP ERN ETB EUR FJD FKP FOK GBP GEL GGP GHS
    GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS IMP
    INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KID KMF KRW
    KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD
    MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO
    NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON
    RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SLL SOS SRD
    SSP STN SYP SZL THB TJS TMT TND TOP TRY TTD TVD TWD
    TZS UAH UGX USD UYU UZS VES VND VUV WST XAF XCD XCG XDR
    XOF XPF YER ZAR ZMW ZWG ZWL
  ''';

  final String code;

  /// Formata o valor para exibição.
  String format(double value) => NumberFormat.currency(
    locale: 'pt_BR',
    name: code,
    symbol: code == 'BRL' ? r'R$' : code,
  ).format(value);
}
