import 'package:flutter/material.dart';

import '../services/wallet_sync_service.dart';
import 'qr_reader.dart';

class WalletForm<T extends Object> extends StatefulWidget {
  /// Inicializa [WalletForm] com os dados recebidos.
  const WalletForm({
    super.key,
    required this.title,
    required this.action,
    required this.fields,
    required this.submit,
    this.description,
    this.initialText,
    this.paymentQr = false,
    this.destructive = false,
    this.contacts = const [],
    this.suggestions = const {},
  });

  final String title;
  final String action;
  final String? description;
  final String? initialText;
  final bool paymentQr;
  final bool destructive;

  /// Sugestões rápidas de preenchimento por índice do campo.
  final Map<int, List<String>> suggestions;

  /// Destinos que podem preencher o primeiro campo (agenda de contatos).
  final List<({String name, String address})> contacts;
  final List<({String label, bool secret, bool amount})> fields;
  final T Function(List<String>) submit;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletForm<T>> createState() => _WalletFormState<T>();
}

class _WalletFormState<T extends Object> extends State<WalletForm<T>> {
  late final _controllers = [
    for (var i = 0; i < widget.fields.length; i++)
      TextEditingController(text: i == 0 ? widget.initialText : null),
  ];
  String? _error;
  bool _qrWorking = false;

  /// Lê um QR para preencher os dados do pagamento.
  Future<void> _readPaymentQr({required bool camera}) async {
    if (_qrWorking) return;
    setState(() => _qrWorking = true);
    try {
      final value = camera
          ? await scanQr(
              context,
              title: 'Ler QR de pagamento',
              accepts: (value) => !value.startsWith(syncPrefix),
            )
          : await readQrImage();
      if (!mounted || value == null) return;
      if (value.startsWith(syncPrefix) || value.length > 1024) {
        throw const FormatException('Este QR não é um pedido de pagamento.');
      }
      setState(() {
        _controllers.first.text = value;
        _error = null;
      });
    } on FormatException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on Exception {
      if (mounted) setState(() => _error = 'Não foi possível ler o QR.');
    } finally {
      if (mounted) setState(() => _qrWorking = false);
    }
  }

  /// Solicita a seleção de o contato.
  Future<void> _pickContact() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Escolher contato',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              for (final contact in widget.contacts)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name.characters.first.toUpperCase()),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(
                    contact.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  onTap: () => Navigator.pop(context, contact.address),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _controllers.first.text = picked;
      _error = null;
    });
  }

  /// Valida os campos e envia o formulário.
  void _submit() {
    try {
      final result = widget.submit([
        for (final field in _controllers) field.text,
      ]);
      Navigator.pop(context, result);
    } on FormatException catch (failure) {
      setState(() => _error = failure.message);
    } on Exception {
      setState(() => _error = 'Não foi possível concluir. Tente novamente.');
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.description case final description?) Text(description),
          for (var i = 0; i < widget.fields.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _controllers[i],
                decoration: InputDecoration(labelText: widget.fields[i].label),
                obscureText: widget.fields[i].secret,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: widget.fields[i].amount
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
            ),
            if (widget.suggestions[i] case final list?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final suggestion in list)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              suggestion,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _controllers[i].text = suggestion;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (widget.paymentQr || widget.contacts.isNotEmpty)
            Wrap(
              children: [
                if (widget.contacts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _qrWorking ? null : _pickContact,
                    icon: const Icon(Icons.contacts_outlined),
                    label: const Text('Contatos'),
                  ),
                if (widget.paymentQr && hasMobileScanner)
                  TextButton.icon(
                    onPressed: _qrWorking
                        ? null
                        : () => _readPaymentQr(camera: true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Ler QR'),
                  ),
                if (widget.paymentQr)
                  TextButton.icon(
                    onPressed: _qrWorking
                        ? null
                        : () => _readPaymentQr(camera: false),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Abrir imagem do QR'),
                  ),
              ],
            ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _qrWorking ? null : _submit,
        style: widget.destructive
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              )
            : null,
        child: Text(widget.action),
      ),
    ],
  );
}
