import 'package:flutter/material.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../models/fiat_currency.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../services/system/security_shield_service.dart';

/// Modal oficial de Confirmação Clara de Transação (Clear Transaction Confirmation).
/// Reduz riscos operacionais com visualização intuitiva de valores, taxas e proteção anti-golpe.
class ClearTransactionConfirmationDialog extends StatefulWidget {
  const ClearTransactionConfirmationDialog({
    super.key,
    required this.account,
    required this.networkLabel,
    required this.recipientAddress,
    this.recipientName,
    required this.amount,
    required this.fee,
    required this.symbol,
    required this.fiatCurrency,
    this.paymentType,
    this.hasPoisonRisk = false,
    this.isPurchase = false,
  });

  final WalletAccount account;
  final String networkLabel;
  final String recipientAddress;
  final String? recipientName;
  final BigInt amount;
  final BigInt fee;
  final String symbol;
  final FiatCurrency fiatCurrency;
  final String? paymentType;
  final bool hasPoisonRisk;
  final bool isPurchase;

  static Future<bool?> show({
    required BuildContext context,
    required WalletAccount account,
    required String networkLabel,
    required String recipientAddress,
    String? recipientName,
    required BigInt amount,
    required BigInt fee,
    required String symbol,
    required FiatCurrency fiatCurrency,
    String? paymentType,
    bool hasPoisonRisk = false,
    bool isPurchase = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClearTransactionConfirmationDialog(
        account: account,
        networkLabel: networkLabel,
        recipientAddress: recipientAddress,
        recipientName: recipientName,
        amount: amount,
        fee: fee,
        symbol: symbol,
        fiatCurrency: fiatCurrency,
        paymentType: paymentType,
        hasPoisonRisk: hasPoisonRisk,
        isPurchase: isPurchase,
      ),
    );
  }

  @override
  State<ClearTransactionConfirmationDialog> createState() =>
      _ClearTransactionConfirmationDialogState();
}

class _ClearTransactionConfirmationDialogState
    extends State<ClearTransactionConfirmationDialog> {
  bool _confirmedCheck = false;

  String _formatCoin(BigInt value) {
    if (widget.symbol.toUpperCase() == 'BTC') {
      return formatBtc(value);
    }
    return formatEth(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBtc = widget.symbol.toUpperCase() == 'BTC';

    final totalAmount = widget.amount + widget.fee;
    final targetEmojis = SecurityShieldService.visualEmojis(widget.recipientAddress);
    final myEmojis = SecurityShieldService.visualEmojis(widget.account.publicAddress);

    // Cotação fiduciária
    final amountDouble = isBtc
        ? widget.amount.toDouble() / 1e8
        : widget.amount.toDouble() / 1e18;
    final fiat = CryptoFinanceService.convertCrypto(
      symbol: widget.symbol,
      amount: amountDouble,
    );
    final fiatText = widget.fiatCurrency.code == 'BRL'
        ? 'R\$ ${fiat.brl.toStringAsFixed(2)}'
        : '\$ ${fiat.usd.toStringAsFixed(2)} USD';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      widget.isPurchase ? Icons.shopping_bag_outlined : Icons.send_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isPurchase
                              ? 'Confirmação de Pagamento'
                              : 'Confirmação Clara de Envio',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Rede: ${widget.networkLabel}',
                          style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Cartão de Destaque de Valor
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_formatCoin(widget.amount)} ${widget.symbol}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ $fiatText',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    if (isBtc) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(${widget.amount} satoshis)',
                        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Alerta Anti-Poisoning
              if (widget.hasPoisonRisk)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ALERTA DE SEGURANÇA: Este endereço se parece com um contato salvo, mas possui caracteres divergentes no meio (possível tentativa de envenenamento). Confira os emojis com o recebedor!',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // Fluxo de Origem e Destino
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    // Remetente
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('De (Remetente):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${widget.account.name} (${widget.account.username}) · $myEmojis',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 18),

                    // Destinatário
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.call_made_rounded, size: 18, color: Colors.teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Para (Destinatário):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                widget.recipientName ?? 'Destinatário On-Chain',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '🛡️ Emojis: $targetEmojis',
                                style: const TextStyle(fontSize: 12),
                              ),
                              SelectableText(
                                widget.recipientAddress,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Detalhes da Taxa e Total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (widget.paymentType != null)
                      _infoRow('Finalidade:', widget.paymentType!),
                    _infoRow(
                      'Taxa de Mineração / Gas:',
                      '${_formatCoin(widget.fee)} ${widget.symbol} (${isBtc ? "~10 min" : "~12s"})',
                    ),
                    const Divider(height: 12),
                    _infoRow(
                      'Total a Débitar:',
                      '${_formatCoin(totalAmount)} ${widget.symbol}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Checkbox de Confirmação Explícita
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _confirmedCheck,
                onChanged: (val) => setState(() => _confirmedCheck = val ?? false),
                title: const Text(
                  'Conferi o endereço e os emojis determinísticos do recebedor.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              const SizedBox(height: 16),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: colors.primary,
                      ),
                      onPressed: _confirmedCheck ? () => Navigator.pop(context, true) : null,
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text(
                        'Assinar & Transmitir',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
