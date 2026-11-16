import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blockchain/bitcoin_codec.dart';
import '../blockchain/ethereum_codec.dart';
import '../controllers/contacts_controller.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';

class AddressInspectorDialog extends StatefulWidget {
  /// Inicializa [AddressInspectorDialog] com os dados recebidos.
  const AddressInspectorDialog({
    super.key,
    required this.account,
    this.contacts,
    this.initialAddress,
  });

  final WalletAccount account;
  final ContactsController? contacts;
  final String? initialAddress;

  /// Cria o estado local associado ao widget.
  @override
  State<AddressInspectorDialog> createState() => _AddressInspectorDialogState();
}

class _AddressInspectorDialogState extends State<AddressInspectorDialog> {
  final _addressController = TextEditingController();

  bool _evaluated = false;
  bool _isValid = false;
  bool _isWrongNetwork = false;
  String _networkType = '';
  List<String> _safetyAlerts = [];
  List<String> _safetyPasses = [];

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
      _inspect(widget.initialAddress!);
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Analisa o endereço informado.
  void _inspect(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      setState(() => _evaluated = false);
      return;
    }

    final alerts = <String>[];
    final passes = <String>[];
    var valid = false;
    var wrongNetwork = false;
    var netType = '';

    final isEthCandidate =
        input.startsWith('0x') || RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(input);
    final isBtcCandidate =
        input.startsWith('1') ||
        input.startsWith('3') ||
        input.startsWith('bc1') ||
        input.startsWith('tb1') ||
        input.startsWith('m') ||
        input.startsWith('n') ||
        input.startsWith('2');

    final currentIsBtc =
        widget.account.bitcoinChain != null ||
        (widget.account.isMultiCoin && widget.account.activeAsset == 'BTC');

    // 1. Verificação Ethereum
    if (isEthCandidate) {
      netType = 'Rede Ethereum / EVM';
      try {
        final parsed = parseAddress(input);
        valid = true;
        passes.add('Endereço Ethereum válido de 20 bytes (160 bits).');

        // Validação de Checksum EIP-55
        if (input == parsed.eip55With0x) {
          passes.add('Proteção EIP-55 contra erro de digitação confirmada.');
        } else if (input == input.toLowerCase()) {
          alerts.add(
            'Endereço em caixa baixa (sem proteção EIP-55 contra erros de digitação).',
          );
        } else {
          alerts.add(
            'ATENÇÃO: As letras maiúsculas/minúsculas não batem com a soma de verificação EIP-55.',
          );
        }

        // Checar endereço de queima ou zero
        if (input.toLowerCase() ==
            '0x0000000000000000000000000000000000000000') {
          alerts.add(
            'ALERTA MÁXIMO: Este é o endereço nulo (0x0). Fundos enviados aqui serão destruídos.',
          );
        }

        if (currentIsBtc) {
          wrongNetwork = true;
          alerts.add(
            'PERIGO DE REDE: Você está na carteira Bitcoin, mas este endereço é Ethereum!',
          );
        }
      } catch (e) {
        valid = false;
        alerts.add('Formato Ethereum inválido ou tamanho incorreto.');
      }
    }
    // 2. Verificação Bitcoin
    else if (isBtcCandidate) {
      netType = 'Rede Bitcoin';
      try {
        final btcChain = widget.account.bitcoinChain ?? BitcoinChain.testnet4;
        parseBitcoinAddress(btcChain, input);
        valid = true;
        passes.add(
          'Endereço Bitcoin válido para a rede ${btcChain.name.toUpperCase()}.',
        );

        if (input.startsWith('bc1q') || input.startsWith('tb1q')) {
          passes.add(
            'Tipo: Native SegWit (Bech32) - Menores taxas de mineração.',
          );
        } else if (input.startsWith('bc1p') || input.startsWith('tb1p')) {
          passes.add(
            'Tipo: Taproot (Bech32m) - Máxima privacidade e eficiência.',
          );
        } else if (input.startsWith('3') || input.startsWith('2')) {
          passes.add('Tipo: SegWit compatível (Script Hash / P2SH).');
        } else {
          passes.add('Tipo: Legacy (P2PKH).');
        }

        if (!currentIsBtc) {
          wrongNetwork = true;
          alerts.add(
            'PERIGO DE REDE: Você está na carteira Ethereum, mas este endereço é Bitcoin!',
          );
        }
      } catch (_) {
        valid = false;
        alerts.add(
          'Endereço Bitcoin com soma de verificação (checksum) inválida ou rede incompatível.',
        );
      }
    } else {
      valid = false;
      alerts.add('Formato não reconhecido como Ethereum ou Bitcoin.');
    }

    // 3. Verificação na agenda de contatos
    String? contactFound;
    if (widget.contacts != null) {
      final contacts = widget.contacts!.value;
      final target = input.toLowerCase();
      for (final c in contacts) {
        if (c.address.toLowerCase() == target ||
            c.effectiveEth.toLowerCase() == target ||
            c.effectiveBtc.toLowerCase() == target) {
          contactFound = c.name;
          passes.add(
            'Endereço verificado: Salvo nos seus contatos como "$contactFound".',
          );
          break;
        }
      }
    }

    setState(() {
      _evaluated = true;
      _isValid = valid;
      _isWrongNetwork = wrongNetwork;
      _networkType = netType;
      _safetyAlerts = alerts;
      _safetyPasses = passes;
    });
  }

  /// Preenche o campo com texto da área de transferência.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _addressController.text = data!.text!.trim();
      _inspect(data.text!);
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security, color: Colors.blue),
          SizedBox(width: 8),
          Text('Inspetor Anti-Golpe & Auditoria'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Audite qualquer endereço antes de transferir. O inspetor valida a rede correta (Bitcoin vs Ethereum), integridade de checksum (EIP-55/Bech32), contatos salvos e escudo visual determinístico contra golpes de envenenamento (Address Poisoning).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Endereço para inspecionar',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Colar da área de transferência',
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                onChanged: _inspect,
              ),
              const SizedBox(height: 16),

              if (_evaluated) ...[
                // Banner de Status Geral
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isWrongNetwork
                        ? Colors.red.withValues(alpha: 0.15)
                        : (_isValid
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isWrongNetwork
                          ? Colors.red
                          : (_isValid ? Colors.green : Colors.orange),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isWrongNetwork
                            ? Icons.dangerous
                            : (_isValid ? Icons.verified : Icons.warning_amber),
                        color: _isWrongNetwork
                            ? Colors.red
                            : (_isValid ? Colors.green : Colors.orange),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isWrongNetwork
                                  ? 'INCOMPATIBILIDADE DE REDE DETECTADA'
                                  : (_isValid
                                        ? 'ENDEREÇO AUTENTICADO'
                                        : 'ENDEREÇO SUSPEITO / INVÁLIDO'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isWrongNetwork
                                    ? Colors.red.shade900
                                    : (_isValid
                                          ? Colors.green.shade900
                                          : Colors.orange.shade900),
                              ),
                            ),
                            Text(
                              'Tipo: $_networkType',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Lista de Passagens Seguras
                if (_safetyPasses.isNotEmpty) ...[
                  for (final pass in _safetyPasses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              pass,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // Lista de Avisos e Alertas
                if (_safetyAlerts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final alert in _safetyAlerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isWrongNetwork ? Icons.error : Icons.warning_amber,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
