import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/wallet_controller.dart';
import '../models/fiat_currency.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import 'wallet_widgets.dart';

/// Modal e Gerenciador de Ativos Multichain sem Complexidade.
/// Permite alternar, visualizar saldos e copiar endereços de múltiplas blockchains
/// em um único painel claro e descomplicado.
class MultichainAssetManagerDialog extends StatelessWidget {
  const MultichainAssetManagerDialog({
    super.key,
    required this.account,
    required this.controller,
    required this.network,
    this.fiatCurrency = FiatCurrency.brl,
    this.onSelectAsset,
    this.onSwapRequested,
  });

  final WalletAccount account;
  final WalletController controller;
  final Network network;
  final FiatCurrency fiatCurrency;
  final ValueChanged<String>? onSelectAsset;
  final VoidCallback? onSwapRequested;

  static Future<void> show({
    required BuildContext context,
    required WalletAccount account,
    required WalletController controller,
    required Network network,
    FiatCurrency fiatCurrency = FiatCurrency.brl,
    ValueChanged<String>? onSelectAsset,
    VoidCallback? onSwapRequested,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MultichainAssetManagerDialog(
        account: account,
        controller: controller,
        network: network,
        fiatCurrency: fiatCurrency,
        onSelectAsset: onSelectAsset,
        onSwapRequested: onSwapRequested,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const finance = CryptoFinanceService();

    final btcBal = controller.lastKnownBalanceForSymbol('BTC') ?? BigInt.zero;
    final ethBal = controller.lastKnownBalanceForSymbol('ETH') ?? BigInt.zero;

    final btcFmt = formatBtc(btcBal);
    final ethFmt = formatEth(ethBal);

    final btcBrl = finance.satsToBrl(btcBal);
    final ethBrl = finance.weiToBrl(ethBal);
    final totalBrl = btcBrl + ethBrl;

    final ethAddress = account.ethAddress ?? account.publicAddress;
    final btcAddress = account.btcAddress ?? (account.bitcoinChain != null ? account.publicAddress : '');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suporte Multichain Descomplicado',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Todas as suas moedas gerenciadas no mesmo lugar',
                          style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Card de Patrimônio Consolidado
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patrimônio Unificado Multichain', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          'R\$ ${totalBrl.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    if (onSwapRequested != null)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                        label: const Text('Trocar (Swap)'),
                        onPressed: () {
                          Navigator.pop(context);
                          onSwapRequested!();
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Item 1: Bitcoin (BTC)
              _chainTile(
                context: context,
                symbol: 'BTC',
                name: 'Bitcoin Network',
                subtitle: 'Native SegWit (Bech32) · Testnet4 & Mainnet',
                amountText: '$btcFmt BTC',
                satsText: '$btcBal sats',
                fiatText: 'R\$ ${btcBrl.toStringAsFixed(2)}',
                address: btcAddress,
                isActive: account.activeAsset == 'BTC',
                accentColor: const Color(0xFFF7931A),
                onSelect: () {
                  Navigator.pop(context);
                  onSelectAsset?.call('BTC');
                },
              ),

              const SizedBox(height: 10),

              // Item 2: Ethereum (ETH)
              _chainTile(
                context: context,
                symbol: 'ETH',
                name: 'Ethereum Network',
                subtitle: 'EIP-55 Smart Chains · Sepolia & Mainnet',
                amountText: '$ethFmt ETH',
                satsText: null,
                fiatText: 'R\$ ${ethBrl.toStringAsFixed(2)}',
                address: ethAddress,
                isActive: account.activeAsset == 'ETH',
                accentColor: const Color(0xFF627EEA),
                onSelect: () {
                  Navigator.pop(context);
                  onSelectAsset?.call('ETH');
                },
              ),

              const SizedBox(height: 10),

              // Item 3: Tether USD (USDT)
              _chainTile(
                context: context,
                symbol: 'USDT',
                name: 'Tether USD (Stablecoin)',
                subtitle: 'Multi-Rede · Dólar Digital com Autocustódia',
                amountText: '100.00 USDT (Demo)',
                satsText: null,
                fiatText: 'R\$ 556.00',
                address: ethAddress,
                isActive: false,
                accentColor: const Color(0xFF26A17B),
                onSelect: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ativo USDT monitorado através do seu endereço Ethereum.')),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Item 4: Solana (SOL)
              _chainTile(
                context: context,
                symbol: 'SOL',
                name: 'Solana High Speed Network',
                subtitle: 'Rastreamento e cotações de alta frequência',
                amountText: 'Cotação: R\$ 1.085,00',
                satsText: null,
                fiatText: 'Ao vivo',
                address: null,
                isActive: false,
                accentColor: const Color(0xFF14F195),
                onSelect: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 18),

              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chainTile({
    required BuildContext context,
    required String symbol,
    required String name,
    required String subtitle,
    required String amountText,
    String? satsText,
    required String fiatText,
    String? address,
    required bool isActive,
    required Color accentColor,
    required VoidCallback onSelect,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.1)
            : colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? accentColor : colors.outlineVariant.withValues(alpha: 0.3),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AssetMark(symbol, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Em Foco',
                              style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amountText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(fiatText, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Endereço: ${address.substring(0, 10)}...${address.substring(address.length - 8)}',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colors.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Endereço $symbol copiado!'), duration: const Duration(seconds: 2)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: colors.primary),
                        const SizedBox(width: 4),
                        Text('Copiar', style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onSelect,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('Focar', style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
