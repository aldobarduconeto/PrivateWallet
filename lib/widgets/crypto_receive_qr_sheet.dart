import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../services/crypto_finance_service.dart';
import '../services/system/security_shield_service.dart';
import 'wallet_widgets.dart';

enum ReceiveQrMode {
  charge('Cobrança / Receber', Icons.request_quote_outlined),
  contactCard('Cartão de Contato', Icons.person_add_alt_1_outlined);

  /// Inicializa a configuração de crypto receive qr sheet.
  const ReceiveQrMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Modal completo de Cobrança via QR Code e Cartão de Contato Soberano.
/// Protegido contra golpes e transferências erradas com conferência visual de 4 emojis e PW-ID.
class CryptoReceiveQrSheet extends StatefulWidget {
  /// Inicializa [CryptoReceiveQrSheet] com os dados recebidos.
  const CryptoReceiveQrSheet({
    super.key,
    required this.account,
    required this.network,
    this.initialMode = ReceiveQrMode.charge,
    this.initialAsset,
  });

  final WalletAccount account;
  final Network network;
  final ReceiveQrMode initialMode;
  final String? initialAsset;

  /// Abre a folha de recebimento com o endereço e seu código QR.
  static Future<void> show(
    BuildContext context, {
    required WalletAccount account,
    required Network network,
    ReceiveQrMode initialMode = ReceiveQrMode.charge,
    String? initialAsset,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CryptoReceiveQrSheet(
        account: account,
        network: network,
        initialMode: initialMode,
        initialAsset: initialAsset,
      ),
    );
  }

  /// Cria o estado local associado ao widget.
  @override
  State<CryptoReceiveQrSheet> createState() => _CryptoReceiveQrSheetState();
}

class _CryptoReceiveQrSheetState extends State<CryptoReceiveQrSheet> {
  static const _finance = CryptoFinanceService();

  late ReceiveQrMode _mode;
  late String _activeAsset;
  bool _includeAmount = false;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _activeAsset = widget.initialAsset ?? widget.account.symbol;
    _amountController.addListener(() => setState(() {}));
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Retorna a conta em uso.
  WalletAccount get _account => widget.account;

  /// Indica se o ativo em uso é Bitcoin.
  bool get _isBtc => _activeAsset == 'BTC';

  /// Retorna `currentAddress` para consulta em crypto receive qr sheet.
  String get _currentAddress {
    if (_account.isMultiCoin) {
      return _isBtc
          ? (_account.btcAddress ?? _account.publicAddress)
          : (_account.ethAddress ?? _account.publicAddress);
    }
    return _account.currentAddress;
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Copia o valor para a área de transferência.
  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _notify('$label copiado para a área de transferência.');
  }

  /// Gera `qr data` no fluxo de crypto receive qr sheet.
  String _generateQrData() {
    if (_mode == ReceiveQrMode.contactCard) {
      return _account.contactSharePayload;
    }

    final address = _currentAddress;
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (!_includeAmount || amount == null || amount <= 0) {
      // Sem valor: gera o esquema direto ou endereço limpo
      if (_isBtc) {
        return 'bitcoin:$address';
      } else {
        return 'ethereum:$address@${widget.network.chainId}';
      }
    }

    if (_isBtc) {
      final sats = BigInt.from((amount * 1e8).round());
      return bitcoinPaymentLink(
        _account.bitcoinChain ?? BitcoinChain.testnet4,
        address,
        sats,
      );
    } else {
      final wei = BigInt.from((amount * 1e18).round());
      return paymentLink(widget.network, parseAddress(address), wei);
    }
  }

  /// Compartilha `via text` no fluxo de crypto receive qr sheet.
  void _shareViaText() {
    final address = _currentAddress;
    final id = _account.uniqueId;
    final username = _account.username;
    final emojis = SecurityShieldService.visualEmojis(address);
    final qrData = _generateQrData();

    final sb = StringBuffer();
    if (_mode == ReceiveQrMode.contactCard) {
      sb.writeln('📇 *CARTÃO DE CONTATO PRIVADO:* ${_account.name}');
      sb.writeln('👤 *Usuário:* $username');
      sb.writeln('🆔 *PW-ID:* $id');
      sb.writeln('🛡️ *Emojis de Conferência Anti-Golpe:* $emojis');
      sb.writeln('\n👉 *Adicione-me pelo link oficial do Private Wallet:*');
      sb.writeln(qrData);
    } else {
      final amountText = _amountController.text.trim();
      final reason = _reasonController.text.trim();

      sb.writeln('⚡ *COBRANÇA PRIVATE WALLET*');
      sb.writeln('👤 *Recebedor:* ${_account.name} ($username)');
      sb.writeln('🆔 *PW-ID:* $id');
      if (_includeAmount && amountText.isNotEmpty) {
        sb.writeln('💰 *Valor Solicitado:* $amountText $_activeAsset');
        final amt = double.tryParse(amountText.replaceAll(',', '.'));
        if (amt != null) {
          final fiat = _isBtc
              ? _finance.satsToBrl(BigInt.from((amt * 1e8).round()))
              : _finance.weiToBrl(BigInt.from((amt * 1e18).round()));
          sb.writeln('💵 *Estimativa:* R\$ ${fiat.toStringAsFixed(2)}');
        }
      }
      if (reason.isNotEmpty) {
        sb.writeln('📝 *Motivo:* $reason');
      }
      sb.writeln('🛡️ *Emojis de Conferência Anti-Golpe:* $emojis');
      sb.writeln('\n🔑 *Chave de Pagamento ($_activeAsset):*');
      sb.writeln(address);
      sb.writeln('\n🔗 *Link de Pagamento Direto:*');
      sb.writeln(qrData);
    }

    _copy(sb.toString(), 'Dados de cobrança e segurança');
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final address = _currentAddress;
    final emojis = SecurityShieldService.visualEmojis(address);
    final qrData = _generateQrData();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Puxador central
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Seletor de Modo (Cobrança vs Cartão de Contato)
            SegmentedButton<ReceiveQrMode>(
              showSelectedIcon: false,
              segments: [
                for (final mode in ReceiveQrMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(mode.icon, size: 16),
                    label: Text(
                      mode.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (val) => setState(() => _mode = val.single),
            ),
            const SizedBox(height: 14),

            // Se for modo de Cobrança e Multi-Moeda, permite escolher entre ETH e BTC
            if (_mode == ReceiveQrMode.charge && _account.isMultiCoin) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    avatar: const AssetMark('ETH', size: 18),
                    label: const Text('Receber ETH'),
                    selected: _activeAsset == 'ETH',
                    onSelected: (val) => setState(() => _activeAsset = 'ETH'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const AssetMark('BTC', size: 18),
                    label: const Text('Receber BTC'),
                    selected: _activeAsset == 'BTC',
                    onSelected: (val) => setState(() => _activeAsset = 'BTC'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Seção de Valor (Opção de colocar valor ou não)
            if (_mode == ReceiveQrMode.charge) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Definir valor na cobrança',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        _includeAmount
                            ? 'O QR Code exigirá o valor exato especificado'
                            : 'O pagador escolhe quanto quer transferir',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: _includeAmount,
                      onChanged: (val) => setState(() => _includeAmount = val),
                    ),
                    if (_includeAmount) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor em $_activeAsset',
                          hintText: '0.00',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              widthFactor: 1.0,
                              child: Text(
                                _activeAsset,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo / Referência (Opcional)',
                          hintText: 'ex: Almoço, Compra, Freelance',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Card Principal do QR Code com Escudo Anti-Golpe
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Cabeçalho de Identidade Padronizado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(_account.name, radius: 14),
                        const SizedBox(width: 8),
                        Text(
                          _account.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        UsernameBadge(_account.username),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // O QR Code em si
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Escudo Visual Anti-Golpe (4 Emojis Imutáveis)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.security,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Escudo Anti-Golpe (Emojis de Conferência):',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emojis,
                            style: const TextStyle(
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID Soberano: ${_account.uniqueId}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Endereço exibido
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              address,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copiar Endereço',
                            onPressed: () => _copy(address, 'Chave pública'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(
                      _mode == ReceiveQrMode.contactCard
                          ? 'Copiar Cartão'
                          : 'Copiar Link',
                    ),
                    onPressed: () => _copy(
                      qrData,
                      _mode == ReceiveQrMode.contactCard
                          ? 'Cartão de contato'
                          : 'Link de pagamento',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Compartilhar'),
                    onPressed: _shareViaText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
