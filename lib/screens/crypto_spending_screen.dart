import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/wallet_controller.dart';
import '../models/fiat_currency.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_activity.dart';
import '../services/crypto_finance_service.dart';
import '../services/system/notification_service.dart';
import '../widgets/crypto_receipt_dialog.dart';
import '../widgets/wallet_layout.dart';
import '../widgets/wallet_widgets.dart';

/// Item de Vale-Presente (Gift Card) disponível para compra com cripto.
class _GiftCardProduct {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final Color brandColor;
  final List<double> availableValuesBrl;

  const _GiftCardProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.brandColor,
    required this.availableValuesBrl,
  });
}

/// Central de Gastos e Pagamentos Cripto no Dia a Dia (Spending Hub).
/// Permite usar Bitcoin e Ethereum em compras cotidianas, cartões-presente, boletos e recargas.
class CryptoSpendingScreen extends StatefulWidget {
  const CryptoSpendingScreen({
    super.key,
    required this.controller,
    required this.account,
    required this.network,
    this.fiatCurrency = FiatCurrency.brl,
    this.onSpendingSuccess,
  });

  final WalletController controller;
  final WalletAccount account;
  final Network network;
  final FiatCurrency fiatCurrency;
  final VoidCallback? onSpendingSuccess;

  @override
  State<CryptoSpendingScreen> createState() => _CryptoSpendingScreenState();
}

class _CryptoSpendingScreenState extends State<CryptoSpendingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _boletoController = TextEditingController();
  final _phoneController = TextEditingController();

  BigInt _btcBalance = BigInt.zero;
  BigInt _ethBalance = BigInt.zero;

  static const _giftCards = [
    _GiftCardProduct(
      id: 'ifood',
      name: 'iFood Refeições',
      category: 'Alimentação',
      icon: Icons.fastfood_rounded,
      brandColor: Color(0xFFEA1D2C),
      availableValuesBrl: [30, 50, 100, 150],
    ),
    _GiftCardProduct(
      id: 'uber',
      name: 'Uber & Uber Eats',
      category: 'Transporte',
      icon: Icons.directions_car_rounded,
      brandColor: Colors.black87,
      availableValuesBrl: [25, 50, 100],
    ),
    _GiftCardProduct(
      id: 'mercadolivre',
      name: 'Mercado Livre',
      category: 'E-commerce',
      icon: Icons.shopping_bag_rounded,
      brandColor: Color(0xFFFFDB15),
      availableValuesBrl: [50, 100, 200, 500],
    ),
    _GiftCardProduct(
      id: 'spotify',
      name: 'Spotify Premium',
      category: 'Música',
      icon: Icons.music_note_rounded,
      brandColor: Color(0xFF1DB954),
      availableValuesBrl: [21.90, 40, 70],
    ),
    _GiftCardProduct(
      id: 'netflix',
      name: 'Netflix Streaming',
      category: 'Filmes & Séries',
      icon: Icons.movie_creation_rounded,
      brandColor: Color(0xFFE50914),
      availableValuesBrl: [50, 70, 150],
    ),
    _GiftCardProduct(
      id: 'steam',
      name: 'Steam Games',
      category: 'Games',
      icon: Icons.sports_esports_rounded,
      brandColor: Color(0xFF171A21),
      availableValuesBrl: [30, 50, 100, 200],
    ),
    _GiftCardProduct(
      id: 'airbnb',
      name: 'Airbnb Viagens',
      category: 'Hospedagem',
      icon: Icons.flight_takeoff_rounded,
      brandColor: Color(0xFFFF5A5F),
      availableValuesBrl: [100, 250, 500],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBalances();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _boletoController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    try {
      final btc = widget.controller.lastKnownBalanceForSymbol('BTC') ??
          await widget.controller.balanceForSymbol('BTC');
      final eth = widget.controller.lastKnownBalanceForSymbol('ETH') ??
          await widget.controller.balanceForSymbol('ETH');
      if (mounted) {
        setState(() {
          _btcBalance = btc;
          _ethBalance = eth;
        });
      }
    } catch (_) {}
  }

  void _buyGiftCard(_GiftCardProduct product, double valBrl) {
    _showPaymentModal(
      title: 'Comprar Vale-Presente: ${product.name}',
      subtitle: 'Crédito de R\$ ${valBrl.toStringAsFixed(2)} para uso imediato',
      amountBrl: valBrl,
      paymentCategory: 'Vale-Presente ${product.name}',
      onSuccessPayload: (code) => 'Código de Resgate (PIN): $code',
    );
  }

  void _payBoleto() {
    final code = _boletoController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (code.length < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a linha digitável válida do boleto bancário (mínimo 30 números).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Simula valor do boleto com base na linha digitável
    final valBrl = 125.50;

    _showPaymentModal(
      title: 'Pagamento de Boleto Bancário',
      subtitle: 'Linha: ${code.substring(0, 15)}...${code.substring(code.length - 8)}',
      amountBrl: valBrl,
      paymentCategory: 'Boleto Bancário',
      onSuccessPayload: (auth) => 'Autenticação Bancária: $auth',
    );
  }

  void _rechargePhone() {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um número de telefone com DDD válido.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    const valBrl = 30.0;
    _showPaymentModal(
      title: 'Recarga de Celular',
      subtitle: 'Número: $phone (Crédito de R\$ 30,00)',
      amountBrl: valBrl,
      paymentCategory: 'Recarga Celular ($phone)',
      onSuccessPayload: (protocol) => 'Protocolo da Operadora: $protocol',
    );
  }

  Future<void> _showPaymentModal({
    required String title,
    required String subtitle,
    required double amountBrl,
    required String paymentCategory,
    required String Function(String authCode) onSuccessPayload,
  }) async {
    const finance = CryptoFinanceService();
    final satsNeeded = finance.brlToSats(amountBrl);
    final weiNeeded = finance.brlToWei(amountBrl);

    String selectedAsset = _btcBalance >= satsNeeded ? 'BTC' : 'ETH';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isBtc = selectedAsset == 'BTC';
          final available = isBtc ? _btcBalance : _ethBalance;
          final needed = isBtc ? satsNeeded : weiNeeded;
          final hasEnough = available >= needed;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor do Pagamento:', style: TextStyle(fontSize: 12.5)),
                          Text(
                            'R\$ ${amountBrl.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Equivalente Cripto:', style: TextStyle(fontSize: 12.5)),
                          Text(
                            isBtc
                                ? '${formatBtc(satsNeeded)} BTC ($satsNeeded sats)'
                                : '${formatEth(weiNeeded)} ETH',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text('Pagar usando:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AssetMark('BTC', size: 18),
                            SizedBox(width: 6),
                            Text('Bitcoin'),
                          ],
                        ),
                        selected: selectedAsset == 'BTC',
                        onSelected: (_) => setModalState(() => selectedAsset = 'BTC'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AssetMark('ETH', size: 18),
                            SizedBox(width: 6),
                            Text('Ethereum'),
                          ],
                        ),
                        selected: selectedAsset == 'ETH',
                        onSelected: (_) => setModalState(() => selectedAsset = 'ETH'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(
                  'Saldo disponível: ${isBtc ? "${formatBtc(_btcBalance)} BTC (${_btcBalance} sats)" : "${formatEth(_ethBalance)} ETH"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasEnough ? Colors.grey : Colors.redAccent,
                    fontWeight: hasEnough ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                if (!hasEnough)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Saldo insuficiente para esta compra.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: hasEnough ? () => Navigator.pop(ctx, selectedAsset) : null,
                child: const Text('Confirmar & Debitar'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    // Executa a compra debitando do saldo
    final isBtc = result == 'BTC';
    final amountSpent = isBtc ? satsNeeded : weiNeeded;
    final rnd = Random.secure();
    final authCode = 'VCH-${rnd.nextInt(900000) + 100000}-${rnd.nextInt(900000) + 100000}';
    final txHash = '0xspend${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';

    final fromAddr = isBtc
        ? (widget.account.btcAddress ?? widget.account.publicAddress)
        : (widget.account.ethAddress ?? widget.account.publicAddress);

    final activity = WalletActivity(
      hash: txHash,
      networkId: isBtc ? (widget.account.bitcoinChain?.name ?? 'testnet4') : widget.network.name,
      bitcoin: isBtc,
      sender: fromAddr,
      recipient: 'Gasto no Dia a Dia ($paymentCategory)',
      amount: amountSpent,
      fee: BigInt.zero,
      created: DateTime.now(),
      paymentType: 'Gasto / Compras ($paymentCategory)',
      purchaseName: '$paymentCategory · R\$ ${amountBrl.toStringAsFixed(2)}',
    );

    await widget.controller.recordActivity(activity);

    // Atualiza saldo local
    if (isBtc) {
      widget.controller.setCachedBalanceForSymbol('BTC', _btcBalance - amountSpent);
      setState(() => _btcBalance -= amountSpent);
    } else {
      widget.controller.setCachedBalanceForSymbol('ETH', _ethBalance - amountSpent);
      setState(() => _ethBalance -= amountSpent);
    }

    await NotificationService.notify(
      title: 'Compra Realizada com Sucesso',
      body: 'Você gastou ${isBtc ? formatBtc(amountSpent) : formatEth(amountSpent)} $result em $paymentCategory.',
    );

    widget.onSpendingSuccess?.call();

    if (!mounted) return;

    // Modal de Sucesso com o Código
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.teal, size: 52),
            SizedBox(height: 8),
            Text('Pagamento Aprovado!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seu pagamento foi liquidado com sucesso com autocustódia soberana.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                onSuccessPayload(authCode),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.teal),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showCryptoReceipt(
                context: context,
                activity: activity,
                ethereumNetwork: widget.network,
                bitcoinChain: widget.account.bitcoinChain,
                fromAddress: fromAddr,
              );
            },
            child: const Text('Ver Comprovante'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Concluir')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return WalletScaffold(
      appBar: AppBar(
        title: const Text('Central de Gastos · Spending Hub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.card_giftcard_rounded), text: 'Vales & Gift Cards'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Pagar Boletos'),
            Tab(icon: Icon(Icons.phone_android_rounded), text: 'Recarga Celular'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGiftCardsTab(colors),
            _buildBoletoTab(colors),
            _buildPhoneTab(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftCardsTab(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Explicativo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_rounded, color: Colors.teal, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gaste Cripto nas Maiores Lojas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('Compre vales-presente com Bitcoin ou Ethereum e resgate na hora.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          for (final gc in _giftCards)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: gc.brandColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(gc.icon, color: gc.brandColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(gc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(gc.category, style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final val in gc.availableValuesBrl)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: Text('R\$ ${val.toStringAsFixed(val % 1 == 0 ? 0 : 2)}'),
                            onPressed: () => _buyGiftCard(gc, val),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoletoTab(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Colors.blueAccent, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento de Contas e Boletos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('Pague água, luz, condomínio e boletos bancários usando seus satoshis ou wei.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _boletoController,
            maxLines: 2,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Linha Digitável do Boleto (47 ou 48 dígitos)',
              hintText: 'Cole a linha digitável do seu boleto aqui...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _boletoController.text = data!.text!;
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.currency_exchange_rounded),
            label: const Text('Consultar e Pagar Boleto com Cripto', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _payBoleto,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneTab(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded, color: Colors.purple, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recarga Instantânea de Celular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('Recarregue créditos nas operadoras Vivo, Claro e TIM com débito direto da carteira.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefone Celular com DDD (ex: 11 99999-9999)',
              hintText: 'Digite o número do celular...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.phone),
            ),
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Recarregar R\$ 30,00 com Cripto', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _rechargePhone,
          ),
        ],
      ),
    );
  }
}
