import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../models/networks.dart';
import '../models/wallet_activity.dart';
import '../services/crypto_finance_service.dart';
import '../services/system/notification_service.dart';
import '../services/system/storage_export_service.dart';
import '../theme/wallet_theme.dart';

/// Modal e exibição de Comprovante Bancário Oficial de Transação Cripto.
Future<void> showCryptoReceipt({
  required BuildContext context,
  required WalletActivity activity,
  required Network? ethereumNetwork,
  required BitcoinChain? bitcoinChain,
  String? fromAddress,
}) async {
  final isEth = bitcoinChain == null;
  final symbol = isEth ? 'ETH' : 'BTC';
  final amountText = isEth
      ? formatEth(activity.amount)
      : formatBtc(activity.amount);
  final feeText = isEth
      ? '${formatEth(activity.estimatedFee)} ETH'
      : '${formatBtc(activity.estimatedFee)} BTC';

  final fiatEstimates = CryptoFinanceService.convertCrypto(
    symbol: symbol,
    amount: isEth
        ? activity.amount.toDouble() / 1e18
        : activity.amount.toDouble() / 1e8,
  );
  final fiatStr =
      'R\$ ${fiatEstimates.brl.toStringAsFixed(2)} · \$ ${fiatEstimates.usd.toStringAsFixed(2)} USD';

  final explorerUrl = isEth
      ? '${(ethereumNetwork ?? Network.sepolia).explorerUrl}/tx/${activity.hash}'
      : '${bitcoinChain.explorerUrl}/tx/${activity.hash}';

  final formattedDate =
      '${activity.created.day.toString().padLeft(2, '0')}/${activity.created.month.toString().padLeft(2, '0')}/${activity.created.year} às ${activity.created.hour.toString().padLeft(2, '0')}:${activity.created.minute.toString().padLeft(2, '0')}:${activity.created.second.toString().padLeft(2, '0')}';

  final receiptText =
      '''
========================================
       COMPROVANTE DE TRANSFERÊNCIA
              PRIVATE WALLET
========================================
Status: Transação Registrada na Blockchain
Data/Hora: $formattedDate
Ativo: $symbol
Valor: $amountText $symbol
Cotação Ref.: $fiatStr
Categoria: ${activity.paymentType}
----------------------------------------
Destinatário:
${activity.to}
${activity.contactName != null ? 'Contato: ${activity.contactName}\n' : ''}
${fromAddress != null ? 'Origem:\n$fromAddress\n' : ''}
Taxa de Rede: $feeText
ID da Transação (TXID / Hash):
${activity.hash}
----------------------------------------
Protocolo: Autocustódia Soberana Descentralizada
Link do Explorador:
$explorerUrl
========================================
''';

  await showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WalletRadius.medium),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Topo com ícone e badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long, color: colors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'COMPROVANTE OFICIAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Transferência $symbol',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Valor grande estilo banco
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(WalletRadius.small),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'VALOR ENVIADO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$amountText $symbol',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fiatStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Linhas de detalhe
                _ReceiptRow(label: 'Data e Hora', value: formattedDate),
                _ReceiptRow(
                  label: 'Tipo / Categoria',
                  value: activity.paymentType ?? 'Transferência Cripto',
                  badge: true,
                ),
                if (activity.contactName != null)
                  _ReceiptRow(
                    label: 'Nome do Contato',
                    value: activity.contactName!,
                  ),
                _ReceiptRow(
                  label: 'Destinatário',
                  value: activity.to,
                  copyable: true,
                  monospace: true,
                ),
                if (fromAddress != null)
                  _ReceiptRow(
                    label: 'Origem',
                    value: fromAddress,
                    copyable: true,
                    monospace: true,
                  ),
                _ReceiptRow(label: 'Taxa da Rede', value: feeText),
                _ReceiptRow(
                  label: 'TXID / Hash On-chain',
                  value: activity.hash,
                  copyable: true,
                  monospace: true,
                ),
                const SizedBox(height: 12),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 12),
                // Selo de Autocustódia
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Autocustódia soberana · Chaves privadas no aparelho',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Botões de Ação
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Salvar Arquivo'),
                        onPressed: () async {
                          final shortHash = activity.hash.length > 8
                              ? activity.hash.substring(0, 8)
                              : activity.hash;
                          final savedPath =
                              await StorageExportService.saveReceiptFile(
                                receiptContent: receiptText,
                                defaultFileName:
                                    'comprovante_${symbol.toLowerCase()}_$shortHash.txt',
                              );
                          if (savedPath != null && context.mounted) {
                            await NotificationService.notify(
                              title: 'Comprovante Salvo com Sucesso! 📄',
                              body: 'Arquivo gravado em $savedPath',
                              context: context,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Copiar'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: receiptText),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comprovante copiado para a área de transferência!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Explorador'),
                        onPressed: () => launchUrl(
                          Uri.parse(explorerUrl),
                          mode: LaunchMode.externalApplication,
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
    },
  );
}

class _ReceiptRow extends StatelessWidget {
  /// Inicializa [_ReceiptRow] com os dados recebidos.
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.monospace = false,
    this.badge = false,
  });

  final String label;
  final String value;
  final bool copyable;
  final bool monospace;
  final bool badge;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: badge
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: monospace ? 12 : 14,
                          fontFamily: monospace ? 'monospace' : null,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
              ),
              if (copyable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copiar',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label copiado!')),
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
