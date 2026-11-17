import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/fiat_currency.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../services/fiat_exchange_service.dart';

class CryptoPosScreen extends StatefulWidget {
  /// Inicializa [CryptoPosScreen] com os dados recebidos.
  const CryptoPosScreen({
    super.key,
    required this.account,
    this.baseCurrency,
  });

  final WalletAccount account;
  final FiatCurrency? baseCurrency;

  /// Cria o estado local associado ao widget.
  @override
  State<CryptoPosScreen> createState() => _CryptoPosScreenState();
}

class _CryptoPosScreenState extends State<CryptoPosScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _currency;
  late String _cryptoSymbol;
  bool _qrGenerated = false;
  Map<String, double>? _rates;

  double _fiatAmount = 0.0;
  double _cryptoAmount = 0.0;
  String _paymentUri = '';

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _currency = widget.baseCurrency?.code ?? 'BRL';
    _cryptoSymbol = widget.account.isMultiCoin
        ? widget.account.activeAsset
        : (widget.account.bitcoinChain != null ? 'BTC' : 'ETH');

    FiatExchangeService.instance.rates().then((r) {
      if (mounted) {
        setState(() {
          _rates = r;
          if (_fiatAmount > 0) _calculateCrypto();
        });
      }
    });
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Abre diálogo para escolher entre todas as moedas governamentais suportadas.
  Future<void> _chooseCurrencyDialog() async {
    final ratesFuture = FiatExchangeService.instance.rates();
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Selecionar Moeda de Cobrança'),
          content: SizedBox(
            width: 360,
            height: 380,
            child: Column(
              children: [
                const Text(
                  'Escolha a moeda governamental para calcular a equivalência em cripto (a moeda base padrão pode ser definida nas Configurações).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar pelo código da moeda',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => query = value.trim().toUpperCase()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<Map<String, double>>(
                    future: ratesFuture,
                    builder: (context, snapshot) {
                      final codes = {
                        ...FiatCurrency.supportedCodes,
                        ...?snapshot.data?.keys,
                      }.where((code) => code.contains(query)).toList()..sort();
                      if (codes.isEmpty) {
                        return const Center(
                          child: Text('Nenhuma moeda encontrada'),
                        );
                      }
                      return ListView.builder(
                        itemCount: codes.length,
                        itemBuilder: (context, index) {
                          final code = codes[index];
                          return ListTile(
                            title: Text(code),
                            selected: code == _currency,
                            onTap: () => Navigator.pop(context, code),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _currency = selected;
        _calculateCrypto();
      });
    }
  }

  /// Calcula o valor equivalente em criptomoeda.
  void _calculateCrypto() {
    final text = _amountController.text.replaceAll(',', '.').trim();
    final fiat = double.tryParse(text) ?? 0.0;
    setState(() {
      _fiatAmount = fiat;
      if (fiat <= 0) {
        _cryptoAmount = 0.0;
        _qrGenerated = false;
        return;
      }

      final isBtc = _cryptoSymbol.toUpperCase() == 'BTC';
      final isBrl = _currency == 'BRL';
      final isUsd = _currency == 'USD';

      double cryptoPriceInCurrency;
      if (isBrl) {
        cryptoPriceInCurrency = isBtc
            ? CryptoFinanceService.btcPriceBrl
            : CryptoFinanceService.ethPriceBrl;
      } else if (isUsd) {
        cryptoPriceInCurrency = isBtc
            ? CryptoFinanceService.btcPriceUsd
            : CryptoFinanceService.ethPriceUsd;
      } else {
        final rate = _rates?[_currency] ?? 1.0;
        final baseUsd = isBtc
            ? CryptoFinanceService.btcPriceUsd
            : CryptoFinanceService.ethPriceUsd;
        cryptoPriceInCurrency = baseUsd * rate;
      }

      _cryptoAmount = cryptoPriceInCurrency > 0
          ? (fiat / cryptoPriceInCurrency)
          : 0.0;
      _paymentUri = _buildPaymentUri();
      _qrGenerated = true;
    });
  }

  /// Monta a URI de pagamento com o endereço e o valor informados.
  String _buildPaymentUri() {
    final address = widget.account.isMultiCoin
        ? (_cryptoSymbol == 'BTC'
              ? (widget.account.btcAddress ?? widget.account.publicAddress)
              : (widget.account.ethAddress ?? widget.account.publicAddress))
        : widget.account.publicAddress;

    final isBtc = _cryptoSymbol.toUpperCase() == 'BTC';
    final desc = _descriptionController.text.trim();

    if (isBtc) {
      final query = [
        'amount=${_cryptoAmount.toStringAsFixed(8)}',
        if (desc.isNotEmpty) 'message=${Uri.encodeComponent(desc)}',
      ].join('&');
      return 'bitcoin:$address?$query';
    } else {
      // Formato padrão EIP-681 para Ethereum
      final query = [
        'value=${(_cryptoAmount * 1e18).toStringAsFixed(0)}',
        if (desc.isNotEmpty) 'label=${Uri.encodeComponent(desc)}',
      ].join('&');
      return 'ethereum:$address?$query';
    }
  }

  /// Copia os dados do pagamento.
  void _copyPaymentDetails() {
    final text =
        'Cobrança PrivateWallet:\nValor de referência: $_currency ${_fiatAmount.toStringAsFixed(2)}\nEquivalente em cripto: ~ ${_cryptoAmount.toStringAsFixed(6)} $_cryptoSymbol\nEndereço: ${widget.account.currentAddress}\nLink: $_paymentUri\n(Aviso: O app não converte moeda governamental; transfira diretamente pela blockchain).';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados da cobrança copiados com sucesso!')),
    );
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobrança Rápida & PDV')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;

          final formInputs = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho explicativo
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.point_of_sale_outlined,
                      color: colors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Modo Ponto de Venda (PDV) & Cobrança Rápida',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Digite o valor na sua moeda governamental e o app calculará a quantia equivalente em criptomoeda para cobrança direta via QR Code.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Alerta importante de soberania e não-conversão governamental
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atenção: O aplicativo não converte dinheiro governamental em criptomoeda (não é uma exchange/on-ramp). Ele apenas calcula e mostra o valor equivalente com base nas cotações de mercado para que o pagador envie BTC ou ETH diretamente para seu endereço.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Moeda de recebimento (se for multicoin)
              if (widget.account.isMultiCoin) ...[
                const Text(
                  'Receber em:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'ETH',
                      label: Text('Ethereum (ETH)'),
                      icon: Icon(Icons.toll),
                    ),
                    ButtonSegment(
                      value: 'BTC',
                      label: Text('Bitcoin (BTC)'),
                      icon: Icon(Icons.currency_bitcoin),
                    ),
                  ],
                  selected: {_cryptoSymbol},
                  onSelectionChanged: (set) {
                    setState(() {
                      _cryptoSymbol = set.first;
                      _calculateCrypto();
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Valor da cobrança e seleção de moeda base
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor da Cobrança',
                        prefixText: '$_currency ',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _calculateCrypto(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _chooseCurrencyDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Moeda Base',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          helperText:
                              _currency == (widget.baseCurrency?.code ?? 'BRL')
                                  ? 'Padrão (Config)'
                                  : 'Personalizada',
                          helperMaxLines: 1,
                        ),
                        child: Text(
                          _currency,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Descrição opcional da fatura
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição ou Nº do Pedido (Opcional)',
                  hintText: 'Ex.: Serviço de design, Pedido #42',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculateCrypto(),
              ),
            ],
          );

          final qrOutput = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_qrGenerated && _fiatAmount > 0) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '$_currency ${_fiatAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Valor equivalente: ~ ${_cryptoAmount.toStringAsFixed(6)} $_cryptoSymbol',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: _paymentUri,
                          size: isWide ? 240 : 210,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aponte a câmera ou carteira cripto para pagar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transfira diretamente em $_cryptoSymbol pela blockchain. Sem intermediários.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _copyPaymentDetails,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Fatura'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Digite um valor ao lado para gerar o QR Code com o valor equivalente em cripto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1040 : 560),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 400 ? 14 : 20,
                  vertical: 20,
                ),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: formInputs),
                          const SizedBox(width: 28),
                          Expanded(flex: 5, child: qrOutput),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          formInputs,
                          const SizedBox(height: 20),
                          qrOutput,
                        ],
                      ),
              ),
            ),
          );
        },
      ),,
    );
  }
}
