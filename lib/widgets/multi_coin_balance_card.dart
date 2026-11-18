import 'package:flutter/material.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../models/fiat_currency.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../theme/wallet_theme.dart';
import 'wallet_widgets.dart';

class MultiCoinBalanceCard extends StatelessWidget {
  /// Inicializa [MultiCoinBalanceCard] com os dados recebidos.
  const MultiCoinBalanceCard({
    super.key,
    required this.account,
    required this.network,
    required this.fiatCurrency,
    required this.exchangeRate,
    required this.ethBalance,
    required this.btcBalance,
    required this.activeBalance,
    required this.hideBalance,
    required this.onToggleHideBalance,
    required this.onSelectAsset,
    required this.onSend,
    required this.onReceive,
    required this.onStatement,
    required this.onFinance,
    required this.onPurchases,
    this.onPos,
    required this.networkBadge,
    this.isSyncing = false,
  });

  final WalletAccount account;
  final Network network;
  final FiatCurrency fiatCurrency;
  final double? exchangeRate;
  final BigInt? ethBalance;
  final BigInt? btcBalance;
  final BigInt? activeBalance;
  final bool hideBalance;
  final VoidCallback onToggleHideBalance;
  final ValueChanged<String> onSelectAsset;
  final VoidCallback? onSend;
  final VoidCallback? onReceive;
  final VoidCallback? onStatement;
  final VoidCallback? onFinance;
  final VoidCallback? onPurchases;
  final VoidCallback? onPos;
  final Widget networkBadge;
  final bool isSyncing;

  static const _finance = CryptoFinanceService();

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    // Cálculo do patrimônio consolidado
    final rate = exchangeRate;
    final total = rate == null
        ? null
        : _finance.valueIn(
                btcBalance ?? BigInt.zero,
                'BTC',
                fiatCurrency,
                rate,
              ) +
              _finance.valueIn(
                ethBalance ?? BigInt.zero,
                'ETH',
                fiatCurrency,
                rate,
              );

    final isMulti = account.isMultiCoin;
    final isBtcActive = account.activeAsset == 'BTC';

    /// Formata o saldo do ativo ou exibe o indicador de carregamento.
    String formatDisplay(BigInt? amount, String symbol) {
      if (amount == null) return '...';
      return symbol == 'BTC' ? formatBtc(amount) : formatEth(amount);
    }

    return BalanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de Cabeçalho
          Row(
            children: [
              if (isMulti)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AssetMark('BTC', size: 28),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: const AssetMark('ETH', size: 28),
                    ),
                  ],
                )
              else
                AssetMark(account.symbol, size: 36),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        UsernameBadge(
                          account.username,
                          color: Colors.lightGreenAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMulti
                          ? 'Conta Principal · Bitcoin & Ethereum'
                          : 'Conta ${account.symbol}',
                      style: const TextStyle(
                        color: Color(0xffa5f3d6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  widthFactor: 1,
                  child: networkBadge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Se for Multi-Moeda: Seletor de Ativo Ativo
          if (isMulti) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AssetTab(
                      symbol: 'BTC',
                      label: 'Bitcoin',
                      balanceText: hideBalance
                          ? '••••'
                          : '${formatDisplay(btcBalance, 'BTC')} BTC',
                      selected: isBtcActive,
                      onTap: () => onSelectAsset('BTC'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AssetTab(
                      symbol: 'ETH',
                      label: 'Ethereum',
                      balanceText: hideBalance
                          ? '••••'
                          : '${formatDisplay(ethBalance, 'ETH')} ETH',
                      selected: !isBtcActive,
                      onTap: () => onSelectAsset('ETH'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Valor em foco
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                isMulti
                    ? 'Saldo em ${account.activeAsset}'
                    : 'Saldo disponível',
                style: const TextStyle(
                  color: walletHeroMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: onToggleHideBalance,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    hideBalance
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 17,
                    color: walletHeroMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Saldo Grande
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  hideBalance
                      ? '••••••'
                      : formatDisplay(activeBalance, account.symbol),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                account.symbol,
                style: const TextStyle(
                  color: walletHeroMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isSyncing) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: walletHeroMuted,
                  ),
                ),
              ],
            ],
          ),

          // Subtítulo de Conversão estimada
          if (!hideBalance && total != null && total > 0) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onFinance,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Aproximadamente ${fiatCurrency.format(total)}',
                      style: const TextStyle(
                        color: Color(0xffa5f3d6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.insights_rounded,
                      size: 13,
                      color: Color(0xffa5f3d6),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botões de Ação Rápida: Design Moderno e Tátil
          Row(
            children: [
              Expanded(
                child: _MainActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Enviar',
                  isPrimary: true,
                  onTap: onSend,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MainActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Receber',
                  isPrimary: false,
                  onTap: onReceive,
                ),
              ),
              if (onPos != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _MainActionButton(
                    icon: Icons.qr_code_rounded,
                    label: 'Cobrar',
                    isPrimary: false,
                    onTap: onPos,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _MainActionButton(
                  icon: Icons.history_rounded,
                  label: 'Histórico',
                  isPrimary: false,
                  onTap: onStatement,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _AssetTab extends StatelessWidget {
  /// Inicializa [_AssetTab] com os dados recebidos.
  const _AssetTab({
    required this.symbol,
    required this.label,
    required this.balanceText,
    required this.selected,
    required this.onTap,
  });

  final String symbol;
  final String label;
  final String balanceText;
  final bool selected;
  final VoidCallback onTap;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              AssetMark(symbol, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : walletHeroMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      balanceText,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xff91efce)
                            : walletHeroMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff91efce),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  const _MainActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? const Color(0xff6366f1)
        : Colors.white.withValues(alpha: 0.11);
    const fg = Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xff818cf8).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xff6366f1).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



