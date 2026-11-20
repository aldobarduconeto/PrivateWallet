import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bip39_service.dart';
import '../services/system/clipboard_guard_service.dart';

/// Modal e visualizador de Frase de Recuperação Secreta (BIP-39).
/// Proporciona autocustódia transparente, teste de verificação e proteção contra vazamentos.
class RecoveryPhraseDialog extends StatefulWidget {
  const RecoveryPhraseDialog({
    super.key,
    required this.hexSecret,
    required this.accountName,
    this.isNewWallet = false,
    this.onConfirmed,
  });

  final String hexSecret;
  final String accountName;
  final bool isNewWallet;
  final VoidCallback? onConfirmed;

  static Future<void> show({
    required BuildContext context,
    required String hexSecret,
    required String accountName,
    bool isNewWallet = false,
    VoidCallback? onConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isNewWallet,
      builder: (_) => RecoveryPhraseDialog(
        hexSecret: hexSecret,
        accountName: accountName,
        isNewWallet: isNewWallet,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<RecoveryPhraseDialog> createState() => _RecoveryPhraseDialogState();
}

class _RecoveryPhraseDialogState extends State<RecoveryPhraseDialog> {
  late final List<String> _words12;
  late final List<String> _words24;
  bool _use24Words = false;
  bool _revealed = false;
  bool _showQuiz = false;

  // Variáveis do Quiz de Confirmação
  int _quizWordIndex = 0;
  List<String> _quizOptions = [];
  int? _selectedOption;
  bool _quizPassed = false;
  String? _quizError;

  @override
  void initState() {
    super.initState();
    // Deriva a frase de 24 palavras diretamente da chave privada de 32 bytes
    final m24 = Bip39Service.privateKeyHexToMnemonic(widget.hexSecret);
    _words24 = m24.split(' ');

    // Deriva a frase de 12 palavras usando os primeiros 16 bytes de entropia
    final entropy12 = Bip39Service.mnemonicToEntropy(m24).sublist(0, 16);
    final m12 = Bip39Service.entropyToMnemonic(entropy12);
    _words12 = m12.split(' ');

    _initQuiz();
  }

  List<String> get _currentWords => _use24Words ? _words24 : _words12;

  void _initQuiz() {
    final words = _currentWords;
    final rnd = Random();
    _quizWordIndex = rnd.nextInt(words.length);
    final correctWord = words[_quizWordIndex];

    final options = <String>{correctWord};
    while (options.length < 4) {
      final randIdx = rnd.nextInt(Bip39Service.totalWords);
      options.add(Bip39Service.generateMnemonic(words: 12).split(' ').first);
    }

    _quizOptions = options.toList()..shuffle();
    _selectedOption = null;
    _quizPassed = false;
    _quizError = null;
  }

  Future<void> _copyPhrase() async {
    final phrase = _currentWords.join(' ');
    await Clipboard.setData(ClipboardData(text: phrase));
    ClipboardGuardService.arm(phrase);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Frase de recuperação copiada para a área de transferência. A área será limpa automaticamente por segurança.',
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _verifyQuizAnswer(int index) {
    setState(() {
      _selectedOption = index;
      final selectedWord = _quizOptions[index];
      final correctWord = _currentWords[_quizWordIndex];

      if (selectedWord == correctWord) {
        _quizPassed = true;
        _quizError = null;
      } else {
        _quizPassed = false;
        _quizError = 'Palavra incorreta. Confira suas anotações e tente novamente.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho com Ícone de Chave e Segurança
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.key_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isNewWallet
                              ? 'Faça Backup da sua Frase Secreta'
                              : 'Frase de Recuperação (BIP-39)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Carteira: ${widget.accountName}',
                          style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Aviso Crítico de Autocustódia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Estas palavras são a chave mestra dos seus fundos. Anote-as na ordem exata e NUNCA as compartilhe com ninguém nem armazene em servidores na nuvem.',
                        style: TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Seletor de 12 vs 24 Palavras
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Formato da Frase:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      _formatPill(
                        label: '12 Palavras',
                        selected: !_use24Words,
                        onTap: () {
                          setState(() {
                            _use24Words = false;
                            _initQuiz();
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _formatPill(
                        label: '24 Palavras',
                        selected: _use24Words,
                        onTap: () {
                          setState(() {
                            _use24Words = true;
                            _initQuiz();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Grade com as Palavras Mnemônicas
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxis = isDesktop ? 4 : 3;
                        final spacing = 8.0;
                        final itemWidth = (constraints.maxWidth - spacing * (crossAxis - 1)) / crossAxis;
                        final words = _currentWords;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (var i = 0; i < words.length; i++)
                              SizedBox(
                                width: itemWidth,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '#${i + 1}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _revealed ? words[i] : '••••••',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    if (!_revealed)
                      Positioned.fill(
                        child: Material(
                          color: colors.surface.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => setState(() => _revealed = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_off_outlined, size: 28, color: Colors.amber),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Toque para Revelar as Palavras',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    'Certifique-se de que ninguém está olhando sua tela',
                                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Barra de Ações: Ocultar/Revelar e Copiar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    label: Text(_revealed ? 'Ocultar Palavras' : 'Revelar Palavras'),
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar Frase'),
                    onPressed: _revealed ? _copyPhrase : null,
                  ),
                ],
              ),

              // Se for criação de carteira nova ou se o usuário quiser testar, mostra o Quiz de Confirmação!
              if (widget.isNewWallet || _showQuiz) ...[
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.quiz_outlined, size: 20, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      'Verificação de Backup (Palavra #${_quizWordIndex + 1})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecione a palavra que você anotou na posição #${_quizWordIndex + 1}:',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _quizOptions.length; i++)
                      ChoiceChip(
                        label: Text(_quizOptions[i]),
                        selected: _selectedOption == i,
                        onSelected: (_) => _verifyQuizAnswer(i),
                      ),
                  ],
                ),

                if (_quizError != null) ...[
                  const SizedBox(height: 8),
                  Text(_quizError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],

                if (_quizPassed) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.teal, size: 18),
                      SizedBox(width: 6),
                      Text('Backup verificado com sucesso!', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Botão de Concluir
              FilledButton(
                onPressed: (widget.isNewWallet && !_quizPassed)
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onConfirmed?.call();
                      },
                child: Text(widget.isNewWallet ? 'Confirmar e Continuar' : 'Concluído'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.amber.shade800 : null,
          ),
        ),
      ),
    );
  }
}
