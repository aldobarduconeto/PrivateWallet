import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/wallet_controller.dart';
import '../models/fiat_currency.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../services/crypto_swap_service.dart';
import '../services/system/notification_service.dart';
import '../theme/wallet_theme.dart';
import '../widgets/crypto_receipt_dialog.dart';
import '../widgets/wallet_layout.dart';
import '../widgets/wallet_widgets.dart';

class CryptoSwapScreen extends StatefulWidget {
  const CryptoSwapScreen({
    super.key,
    required this.controller,
    required this.account,
    required this.network,
    this.fiatCurrency = const FiatCurrency('BRL', 'R\$', 'Real Brasileiro'),
    this.initialFromSymbol,
    this.onSwapSuccess,
  });

  final WalletController controller;
  final WalletAccount account;
  final Network network;
  final FiatCurrency fiatCurrency;
  final String? initialFromSymbol;
  final VoidCallback? onSwapSuccess;

  @override
  State<CryptoSwapScreen> createState() => _CryptoSwapScreenState();
}

class _CryptoSwapScreenState extends State<CryptoSwapScreen> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  String _fromSymbol = 'BTC';
  String _toSymbol = 'ETH';
  BitcoinUnit _btcUnit = BitcoinUnit.btc;
  double _slippage = 0.5;

  BigInt _btcBalance = BigInt.zero;
  BigInt _ethBalance = BigInt.zero;
  bool _loadingBalances = true;
  bool _isSwapping = false;

  SwapQuote? _currentQuote;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialFromSymbol != null &&
        widget.initialFromSymbol!.toUpperCase() == 'ETH') {
      _fromSymbol = 'ETH';
      _toSymbol = 'BTC';
    } else if (!widget.account.isMultiCoin &&
        widget.account.bitcoinChain == null) {
      // Conta apenas Ethereum
      _fromSymbol = 'ETH';
      _toSymbol = 'BTC';
    } else {
      _fromSymbol = 'BTC';
      _toSymbol = 'ETH';
    }
    _loadBalances();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    setState(() => _loadingBalances = true);
    try {
      final btc =
          widget.controller.lastKnownBalanceForSymbol('BTC') ??
          await widget.controller.balanceForSymbol('BTC');
      final eth =
          widget.controller.lastKnownBalanceForSymbol('ETH') ??
          await widget.controller.balanceForSymbol('ETH');
      if (mounted) {
        setState(() {
          _btcBalance = btc;
          _ethBalance = eth;
          _loadingBalances = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _btcBalance =
              widget.controller.lastKnownBalanceForSymbol('BTC') ?? BigInt.zero;
          _ethBalance =
              widget.controller.lastKnownBalanceForSymbol('ETH') ?? BigInt.zero;
          _loadingBalances = false;
        });
      }
    }
  }

  BigInt get _activeSourceBalance =>
      _fromSymbol == 'BTC' ? _btcBalance : _ethBalance;

  BigInt get _activeTargetBalance =>
      _toSymbol == 'BTC' ? _btcBalance : _ethBalance;

  void _onInputChanged() {
    final text = _inputController.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      setState(() {
        _currentQuote = null;
        _errorMessage = null;
      });
      return;
    }

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() {
        _currentQuote = null;
        _errorMessage = 'Informe um valor válido.';
      });
      return;
    }

    try {
      final quote = CryptoSwapService.calculateQuote(
        fromSymbol: _fromSymbol,
        toSymbol: _toSymbol,
        inputAmount: amount,
        btcUnit: _btcUnit,
        slippagePercent: _slippage,
      );

      String? err;
      if (quote.fromAmount > _activeSourceBalance &&
          _activeSourceBalance > BigInt.zero) {
        err = 'Saldo insuficiente de $_fromSymbol.';
      }

      setState(() {
        _currentQuote = quote;
        _errorMessage = err;
      });
    } catch (e) {
      setState(() {
        _currentQuote = null;
        _errorMessage = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _switchDirection() {
    HapticFeedback.lightImpact();
    setState(() {
      final prevFrom = _fromSymbol;
      _fromSymbol = _toSymbol;
      _toSymbol = prevFrom;
      _inputController.clear();
      _currentQuote = null;
      _errorMessage = null;
    });
  }

  void _applyPercentage(double pct) {
    HapticFeedback.selectionClick();
    final balance = _activeSourceBalance;
    if (balance <= BigInt.zero) {
      _showDemoBalanceDialog();
      return;
    }

    if (_fromSymbol == 'BTC') {
      if (_btcUnit == BitcoinUnit.satoshis) {
        final sats = (balance.toDouble() * pct).round();
        _inputController.text = sats.toString();
      } else {
        final btc = (balance.toDouble() / 1e8) * pct;
        _inputController.text = btc.toStringAsFixed(8);
      }
    } else {
      final eth = (balance.toDouble() / 1e18) * pct;
      _inputController.text = eth.toStringAsFixed(6);
    }
  }

  void _injectDemoBalance() {
    // Adiciona saldo demo/testnet para testes do usuário
    final newBtc = BigInt.from(5000000); // 0.05 BTC (5 milhões de satoshis)
    final newEth = BigInt.parse('1500000000000000000'); // 1.5 ETH

    widget.controller.setCachedBalanceForSymbol('BTC', newBtc);
    widget.controller.setCachedBalanceForSymbol('ETH', newEth);

    setState(() {
      _btcBalance = newBtc;
      _ethBalance = newEth;
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saldo de testes adicionado: 0.05 BTC (5.000.000 sats) e 1.5 ETH.',
        ),
        backgroundColor: Colors.teal,
      ),
    );

    _onInputChanged();
  }

  void _showDemoBalanceDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text('Saldo de Demonstração'),
          ],
        ),
        content: const Text(
          'Sua carteira está sem saldo no momento. Deseja adicionar um saldo simulado de 0.05 BTC (5.000.000 satoshis) e 1.5 ETH para testar o recurso de Troca de Moedas (Swap)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Saldo Demo'),
            onPressed: () {
              Navigator.pop(ctx);
              _injectDemoBalance();
            },
          ),
        ],
      ),
    );
  }

  String _resolveDestinationAddress() {
    if (widget.account.isMultiCoin) {
      if (_toSymbol == 'ETH') {
        return widget.account.ethAddress ?? widget.account.publicAddress;
      } else {
        return widget.account.btcAddress ?? widget.account.publicAddress;
      }
    }
    return widget.account.publicAddress;
  }

  Future<void> _confirmAndExecuteSwap() async {
    final quote = _currentQuote;
    if (quote == null) return;

    if (_activeSourceBalance < quote.fromAmount) {
      _showDemoBalanceDialog();
      return;
    }

    final destAddress = _resolveDestinationAddress();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Confirmar Troca (Swap)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revise os detalhes da operação antes de confirmar:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            _summaryRow('Você paga:', quote.formattedFrom),
            if (quote.fromSatsDetail != null)
              _summaryRow('Equivalência:', quote.fromSatsDetail!),
            const Divider(height: 18),
            _summaryRow('Você recebe:', quote.formattedTo),
            if (quote.toSatsDetail != null)
              _summaryRow('Em satoshis:', quote.toSatsDetail!),
            const Divider(height: 18),
            _summaryRow(
              'Taxa de Câmbio:',
              _fromSymbol == 'BTC'
                  ? '1 BTC ≈ ${quote.rate.toStringAsFixed(4)} ETH'
                  : '1 ETH ≈ ${quote.rate.toStringAsFixed(6)} BTC',
            ),
            _summaryRow('Taxa de Protocolo:', quote.formattedFee),
            _summaryRow(
              'Slippage Tolerado:',
              '${quote.slippagePercent}% (Mín: ${quote.formattedMinReceived})',
            ),
            const SizedBox(height: 8),
            _summaryRow(
              'Destino:',
              '${destAddress.substring(0, 10)}...${destAddress.substring(destAddress.length - 8)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirmar & Executar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSwapping = true);

    try {
      final result = await CryptoSwapService.executeSwap(
        controller: widget.controller,
        account: widget.account,
        network: widget.network,
        quote: quote,
        destinationAddress: destAddress,
        currentSourceBalance: _activeSourceBalance,
        currentTargetBalance: _activeTargetBalance,
      );

      await NotificationService.notify(
        title: 'Troca de Moedas Concluída',
        body:
            'Você trocou ${quote.formattedFrom} por ${quote.formattedTo} com sucesso!',
      );

      if (!mounted) return;

      setState(() {
        _isSwapping = false;
        if (_fromSymbol == 'BTC') {
          _btcBalance -= quote.fromAmount;
          _ethBalance += quote.toAmount;
        } else {
          _ethBalance -= quote.fromAmount;
          _btcBalance += quote.toAmount;
        }
        _inputController.clear();
        _currentQuote = null;
      });

      widget.onSwapSuccess?.call();

      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSwapping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha no swap: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(SwapResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 54),
            SizedBox(height: 10),
            Text(
              'Troca Realizada com Sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Os fundos foram convertidos e já estão creditados na sua conta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _summaryRow('Enviado:', result.quote.formattedFrom),
                  const SizedBox(height: 4),
                  _summaryRow('Recebido:', result.quote.formattedTo),
                  if (result.quote.toSatsDetail != null) ...[
                    const SizedBox(height: 4),
                    _summaryRow('Satoshis:', result.quote.toSatsDetail!),
                  ],
                  const SizedBox(height: 4),
                  _summaryRow(
                    'TXID:',
                    '${result.txHash.substring(0, 10)}...${result.txHash.substring(result.txHash.length - 8)}',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Comprovante Oficial'),
            onPressed: () {
              Navigator.pop(ctx);
              showCryptoReceipt(
                context: context,
                activity: result.activity,
                ethereumNetwork: widget.network,
                bitcoinChain: widget.account.bitcoinChain,
                fromAddress: result.fromAddress,
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;

    return WalletScaffold(
      appBar: AppBar(
        title: const Text('Troca de Moedas · Swap Cripto'),
        actions: [
          IconButton(
            tooltip: 'Adicionar saldo simulado (Demo)',
            icon: const Icon(Icons.science_outlined),
            onPressed: _showDemoBalanceDialog,
          ),
          IconButton(
            tooltip: 'Atualizar saldos',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBalances,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho de Cotação ao Vivo
                  _buildMarketRateBanner(colors),

                  const SizedBox(height: 16),

                  // Cartão 1: Você Paga (Origem)
                  _buildSourceCard(colors),

                  const SizedBox(height: 10),

                  // Botão central de inverter direção
                  Center(child: _buildSwitchButton(colors)),

                  const SizedBox(height: 10),

                  // Cartão 2: Você Recebe (Destino)
                  _buildTargetCard(colors),

                  const SizedBox(height: 16),

                  // Detalhes da Cotação / Liquidez
                  if (_currentQuote != null) _buildDetailsCard(colors),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (_errorMessage!.contains('Saldo insuficiente'))
                            TextButton(
                              onPressed: _showDemoBalanceDialog,
                              child: const Text('Adicionar Saldo'),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botão de Ação Principal
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed:
                        (_currentQuote != null &&
                            _errorMessage == null &&
                            !_isSwapping)
                        ? _confirmAndExecuteSwap
                        : null,
                    child: _isSwapping
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.currency_exchange_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fromSymbol == 'BTC'
                                    ? (_btcUnit == BitcoinUnit.satoshis
                                          ? 'Trocar Satoshis por Ethereum'
                                          : 'Trocar Bitcoin por Ethereum')
                                    : (_btcUnit == BitcoinUnit.satoshis
                                          ? 'Trocar Ethereum por Satoshis'
                                          : 'Trocar Ethereum por Bitcoin'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 14),

                  // Nota de Autocustódia
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        size: 14,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Autocustódia Soberana · Sem intermediários ou custódia externa',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketRateBanner(ColorScheme colors) {
    final btcToEth = CryptoSwapService.btcToEthRate;
    final ethToSats = CryptoSwapService.ethToSatoshis;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF10B981),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cotação Direta do Mercado',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                Text(
                  '1 BTC ≈ ${btcToEth.toStringAsFixed(2)} ETH   •   1 ETH ≈ ${SwapQuote._formatWithThousands(ethToSats.toInt())} satoshis',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(ColorScheme colors) {
    final isBtc = _fromSymbol == 'BTC';
    final bal = _activeSourceBalance;
    final balText = isBtc
        ? (_btcUnit == BitcoinUnit.satoshis
              ? '${SwapQuote._formatWithThousands(bal.toInt())} sats'
              : '${formatBtc(bal)} BTC')
        : '${formatEth(bal)} ETH';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Você Paga (Origem)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Saldo: $balText',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _applyPercentage(1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'MÁX',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge do Ativo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isBtc
                      ? const Color(0xFFF7931A).withValues(alpha: 0.15)
                      : const Color(0xFF627EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBtc
                        ? const Color(0xFFF7931A).withValues(alpha: 0.3)
                        : const Color(0xFF627EEA).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetMark(_fromSymbol, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      isBtc ? 'Bitcoin' : 'Ethereum',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Campo de Entrada do Valor
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: isBtc
                        ? (_btcUnit == BitcoinUnit.satoshis ? '0 sats' : '0.0')
                        : '0.0',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),

          // Se for Bitcoin, mostra o Toggle entre BTC e Satoshis!
          if (isBtc) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Unidade:',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                _unitPill(
                  label: 'BTC',
                  selected: _btcUnit == BitcoinUnit.btc,
                  onTap: () {
                    setState(() => _btcUnit = BitcoinUnit.btc);
                    _onInputChanged();
                  },
                ),
                const SizedBox(width: 6),
                _unitPill(
                  label: 'Satoshis (sats)',
                  selected: _btcUnit == BitcoinUnit.satoshis,
                  onTap: () {
                    setState(() => _btcUnit = BitcoinUnit.satoshis);
                    _onInputChanged();
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Botões de porcentagem rápida
          Row(
            children: [
              _percentChip('25%', 0.25),
              const SizedBox(width: 6),
              _percentChip('50%', 0.50),
              const SizedBox(width: 6),
              _percentChip('75%', 0.75),
              const SizedBox(width: 6),
              _percentChip('100%', 1.00),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF7931A).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFFF7931A)
                : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? const Color(0xFFF7931A) : null,
          ),
        ),
      ),
    );
  }

  Widget _percentChip(String label, double pct) {
    return InkWell(
      onTap: () => _applyPercentage(pct),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSwitchButton(ColorScheme colors) {
    return Material(
      color: const Color(0xFF10B981).withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _switchDirection,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.swap_vert_rounded,
            color: Color(0xFF10B981),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(ColorScheme colors) {
    final isBtc = _toSymbol == 'BTC';
    final bal = _activeTargetBalance;
    final balText = isBtc
        ? (_btcUnit == BitcoinUnit.satoshis
              ? '${SwapQuote._formatWithThousands(bal.toInt())} sats'
              : '${formatBtc(bal)} BTC')
        : '${formatEth(bal)} ETH';

    final quote = _currentQuote;
    final targetValueText = quote != null ? quote.formattedTo : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Você Recebe (Destino)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                'Saldo atual: $balText',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge do Ativo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isBtc
                      ? const Color(0xFFF7931A).withValues(alpha: 0.15)
                      : const Color(0xFF627EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBtc
                        ? const Color(0xFFF7931A).withValues(alpha: 0.3)
                        : const Color(0xFF627EEA).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetMark(_toSymbol, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      isBtc ? 'Bitcoin' : 'Ethereum',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Valor Calculado de Saída
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetValueText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: quote != null ? const Color(0xFF10B981) : null,
                      ),
                    ),
                    if (quote?.toSatsDetail != null)
                      Text(
                        quote!.toSatsDetail!,
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

          // Se o destino for Bitcoin, permite alternar visualização
          if (isBtc) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Exibir em:',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                _unitPill(
                  label: 'Satoshis (sats)',
                  selected: _btcUnit == BitcoinUnit.satoshis,
                  onTap: () {
                    setState(() => _btcUnit = BitcoinUnit.satoshis);
                    _onInputChanged();
                  },
                ),
                const SizedBox(width: 6),
                _unitPill(
                  label: 'BTC',
                  selected: _btcUnit == BitcoinUnit.btc,
                  onTap: () {
                    setState(() => _btcUnit = BitcoinUnit.btc);
                    _onInputChanged();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ColorScheme colors) {
    final quote = _currentQuote!;
    final dest = _resolveDestinationAddress();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detalhes da Transação',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Liquidação Imediata',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Taxa de Conversão:',
            _fromSymbol == 'BTC'
                ? '1 BTC = ${quote.rate.toStringAsFixed(4)} ETH'
                : '1 ETH = ${quote.rate.toStringAsFixed(6)} BTC',
          ),
          _summaryRow(
            'Equivalência em Satoshis:',
            '1 ETH ≈ ${SwapQuote._formatWithThousands(CryptoSwapService.ethToSatoshis.toInt())} sats',
          ),
          _summaryRow('Taxa de Protocolo (0,25%):', quote.formattedFee),
          _summaryRow(
            'Slippage Máximo Tolerado:',
            '${quote.slippagePercent}% (Garantido: ${quote.formattedMinReceived})',
          ),
          _summaryRow(
            'Endereço de Recebimento:',
            '${dest.substring(0, 10)}...${dest.substring(dest.length - 8)}',
          ),
        ],
      ),
    );
  }
}
