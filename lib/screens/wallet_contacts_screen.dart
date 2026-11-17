import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/contacts_controller.dart';
import '../controllers/group_purchase_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_contact.dart';
import '../services/system/security_shield_service.dart';
import '../widgets/crypto_receive_qr_sheet.dart';
import '../widgets/qr_reader.dart';
import '../widgets/wallet_form.dart';
import '../widgets/wallet_widgets.dart';
import 'group_purchases_screen.dart';

/// Agenda de destinatários frequentes e amigos do Private Wallet.
class WalletContactsScreen extends StatefulWidget {
  /// Inicializa [WalletContactsScreen] com os dados recebidos.
  const WalletContactsScreen({
    super.key,
    required this.contacts,
    this.account,
    this.network = Network.sepolia,
    this.groupPurchases,
    this.onSendToContact,
  });

  final ContactsController contacts;
  final WalletAccount? account;
  final Network network;
  final GroupPurchaseController? groupPurchases;
  final void Function(WalletContact contact, String asset)? onSendToContact;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletContactsScreen> createState() => _WalletContactsScreenState();
}

enum _Filter {
  all('Todos'),
  ethereum('Ethereum'),
  bitcoin('Bitcoin');

  /// Inicializa a configuração de agenda de contatos.
  const _Filter(this.label);
  final String label;

  /// Aplica o critério de seleção ao item recebido.
  bool accepts(WalletContact contact) => switch (this) {
    _Filter.all => true,
    _Filter.ethereum => contact.hasEth,
    _Filter.bitcoin => contact.hasBtc,
  };
}

class _WalletContactsScreenState extends State<WalletContactsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  bool _busy = false;

  /// Retorna os contatos em uso.
  ContactsController get _contacts => widget.contacts;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (!_contacts.loaded) {
      _contacts.load().catchError((_) {
        if (mounted) _notify('Não foi possível ler a agenda.');
      });
    }
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Executa a operação de contato e encaminha erros para a interface.
  Future<void> _run(Future<void> Function() action, String error) async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      await action();
    } on FormatException catch (failure) {
      _notify(failure.message);
    } catch (_) {
      _notify(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Exibe `my contact qr` no fluxo de agenda de contatos.
  void _showMyContactQr() {
    final acc = widget.account;
    if (acc == null || acc.publicAddress.isEmpty) {
      _notify('Nenhuma carteira ativa selecionada.');
      return;
    }

    CryptoReceiveQrSheet.show(
      context,
      account: acc,
      network: widget.network,
      initialMode: ReceiveQrMode.contactCard,
    );
  }

  /// Adiciona `choice` no fluxo de agenda de contatos.
  Future<void> _addChoice() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Adicionar Amigo / Contato',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.qr_code_scanner,
                color: Colors.blueAccent,
              ),
              title: const Text('Escanear QR Code com a Câmera'),
              subtitle: const Text(
                'Conexão instantânea sem risco de digitação errada',
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.green),
              title: const Text('Ler Imagem de QR Code do Aparelho'),
              subtitle: const Text('Importe uma imagem salva ou screenshot'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.paste_outlined, color: Colors.orange),
              title: const Text('Colar Código ou Link do Amigo (PW-ID)'),
              subtitle: const Text(
                'Importa Nome, @username, ID e Chaves ETH + BTC',
              ),
              onTap: () => Navigator.pop(ctx, 'code'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Inserir Endereço Manualmente'),
              subtitle: const Text(
                'Cadastre informando a rede e chave pública',
              ),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'camera') {
      await _scanQrFromCamera();
    } else if (choice == 'image') {
      await _scanQrFromImage();
    } else if (choice == 'code') {
      await _addViaCode();
    } else {
      await _addManual();
    }
  }

  /// Escaneia `qr from camera` no fluxo de agenda de contatos.
  Future<void> _scanQrFromCamera() async {
    final raw = await scanQr(
      context,
      title: 'Escanear QR Code de Amigo',
      accepts: (val) => val.trim().isNotEmpty,
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    await _processScannedPayload(raw.trim());
  }

  /// Escaneia `qr from image` no fluxo de agenda de contatos.
  Future<void> _scanQrFromImage() async {
    try {
      final raw = await readQrImage();
      if (!mounted || raw == null || raw.trim().isEmpty) return;
      await _processScannedPayload(raw.trim());
    } catch (e) {
      _notify('Não foi possível ler a imagem do QR Code.');
    }
  }

  /// Processa os dados lidos do QR.
  Future<void> _processScannedPayload(String payload) async {
    final trimmed = payload.trim();

    // 1. Caso seja um Cartão de Contato P2P ou JSON
    if (trimmed.startsWith('pw://contact') ||
        (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
      try {
        final contact = WalletContact.fromPayload(
          trimmed,
          defaultBitcoin: widget.account?.bitcoinChain ?? BitcoinChain.testnet4,
        );
        await _confirmAndAddContact(contact);
        return;
      } catch (_) {}
    }

    // 2. Caso seja um código PW-ID puro
    if (trimmed.startsWith('PW-') && trimmed.length == 11) {
      _notify(
        'ID identificado. Digite o endereço ou utilize o QR completo de contato.',
      );
      return;
    }

    // 3. Caso seja um endereço Ethereum ou Bitcoin puro
    if (SecurityShieldService.isValidAddress(trimmed) ||
        SecurityShieldService.isValidAddress(
          trimmed,
          bitcoin: widget.account?.bitcoinChain ?? BitcoinChain.testnet4,
        )) {
      final isBtc = SecurityShieldService.isValidAddress(
        trimmed,
        bitcoin: widget.account?.bitcoinChain ?? BitcoinChain.testnet4,
      );
      final contact = WalletContact.parse(
        'Amigo',
        trimmed,
        bitcoin: isBtc
            ? (widget.account?.bitcoinChain ?? BitcoinChain.testnet4)
            : null,
      );
      await _confirmAndAddContact(contact);
      return;
    }

    _notify('Formato de QR Code não reconhecido como contato ou cobrança.');
  }

  /// Confirma `and add contact` no fluxo de agenda de contatos.
  Future<void> _confirmAndAddContact(WalletContact contact) async {
    final colors = Theme.of(context).colorScheme;
    final address = contact.effectiveEth.isNotEmpty
        ? contact.effectiveEth
        : contact.address;
    final emojis = SecurityShieldService.visualEmojis(address);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Contato Verificado Encontrado!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          UserAvatar(contact.name, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (contact.username != null)
                                  UsernameBadge(contact.username!),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Escudo Anti-Golpe (Conferência Visual):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emojis,
                              style: const TextStyle(
                                fontSize: 18,
                                letterSpacing: 2,
                              ),
                            ),
                            if (contact.uniqueId != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ID Soberano: ${contact.uniqueId}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        address,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Adicionar Contato'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _run(() async {
        await _contacts.addOrUpdate(contact);
        _notify('Amigo "${contact.name}" adicionado à sua agenda!');
      }, 'Não foi possível salvar o contato.');
    }
  }

  /// Adiciona `via code` no fluxo de agenda de contatos.
  Future<void> _addViaCode() async {
    final codeCtrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar via Código / ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o link do contato (pw://contact...), o identificador PW-ID ou os dados compartilhados pelo seu amigo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'pw://contact?id=PW-... ou cole aqui',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;
    await _processScannedPayload(result);
  }

  /// Adiciona `manual` no fluxo de agenda de contatos.
  Future<void> _addManual() => _run(() async {
    final chain = await showModalBottomSheet<_ContactNetwork>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Rede do contato',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in _ContactNetwork.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: AssetMark(option.symbol, size: 34),
                title: Text(option.label),
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || chain == null) return;
    final contact = await showDialog<WalletContact>(
      context: context,
      builder: (_) => WalletForm(
        title: 'Novo contato',
        description: chain.label,
        action: 'Salvar contato',
        fields: const [
          (label: 'Nome', secret: false, amount: false),
          (label: 'Endereço público', secret: false, amount: false),
        ],
        submit: (values) =>
            WalletContact.parse(values[0], values[1], bitcoin: chain.bitcoin),
      ),
    );
    if (!mounted || contact == null) return;
    await _contacts.add(contact);
    _notify('Contato salvo.');
  }, 'Não foi possível salvar o contato.');

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> _remove(WalletContact contact) => _run(() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover contato?'),
        content: Text('“${contact.name}” sairá da agenda deste aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _contacts.remove(contact);
  }, 'Não foi possível remover o contato.');

  /// Copia o valor para a área de transferência.
  Future<void> _copy(WalletContact contact) async {
    await Clipboard.setData(ClipboardData(text: contact.address));
    _notify('Endereço copiado.');
  }

  /// Solicita `payment from contact` no fluxo de agenda de contatos.
  void _requestPaymentFromContact(WalletContact contact) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Acerto');
    var asset = widget.account?.symbol ?? 'ETH';
    var includeAmount = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final myAccount = widget.account;
          final colors = Theme.of(ctx).colorScheme;
          final myAddr = myAccount?.currentAddress ?? '';
          final myEmojis = SecurityShieldService.visualEmojis(myAddr);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.request_quote_outlined, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cobrar ${contact.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Especificar valor da cobrança',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      value: includeAmount,
                      onChanged: (val) =>
                          setSheetState(() => includeAmount = val),
                    ),
                    if (includeAmount) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Valor ($asset)',
                                hintText: '0.01',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 'ETH', label: Text('ETH')),
                              ButtonSegment(value: 'BTC', label: Text('BTC')),
                            ],
                            selected: {asset},
                            onSelectionChanged: (val) =>
                                setSheetState(() => asset = val.single),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motivo / Referência',
                        hintText: 'ex: Almoço, Gasolina, Compra',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (myAccount != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Conferência Anti-Golpe (Seus Emojis de Segurança):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              myEmojis,
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu ID: ${myAccount.uniqueId} (${myAccount.username})',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    FilledButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Copiar Mensagem de Cobrança'),
                      onPressed: () {
                        final amt = amountCtrl.text.trim();
                        final reason = reasonCtrl.text.trim();
                        final myId = myAccount?.uniqueId ?? '';
                        final myUser = myAccount?.username ?? '';

                        final sb = StringBuffer();
                        sb.writeln(
                          'Olá ${contact.username ?? contact.name}! 👋',
                        );
                        sb.writeln(
                          'Segue os dados para acerto seguro no Private Wallet:',
                        );
                        if (includeAmount && amt.isNotEmpty) {
                          sb.writeln('💰 *Valor:* $amt $asset');
                        }
                        if (reason.isNotEmpty) {
                          sb.writeln('📝 *Motivo:* $reason');
                        }
                        if (myAddr.isNotEmpty) {
                          sb.writeln(
                            '🔑 *Chave de recebimento ($asset):* $myAddr',
                          );
                        }
                        sb.writeln(
                          '🛡️ *Emojis de Conferência Anti-Golpe:* $myEmojis',
                        );
                        if (myId.isNotEmpty) {
                          sb.writeln('🆔 *ID Soberano:* $myId ($myUser)');
                        }

                        Clipboard.setData(ClipboardData(text: sb.toString()));
                        Navigator.pop(ctx);
                        _notify('Mensagem de cobrança copiada para enviar!');
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Abre `group purchases with contact` no fluxo de agenda de contatos.
  void _openGroupPurchasesWithContact(WalletContact contact) {
    if (widget.groupPurchases == null) {
      _notify('Módulo de Compras Conjuntas indisponível.');
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPurchasesScreen(
          controller: widget.groupPurchases!,
          contacts: widget.contacts,
          account: widget.account,
          initialContact: contact,
        ),
      ),
    );
  }

  /// Processa `send` no fluxo de agenda de contatos.
  void _handleSend(WalletContact contact) {
    if (widget.onSendToContact == null) {
      _copy(contact);
      return;
    }

    if (contact.isMultiCoin) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Enviar para ${contact.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: const AssetMark('ETH', size: 30),
                title: const Text('Enviar Ethereum (ETH)'),
                subtitle: Text(shortAddress(contact.effectiveEth)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  widget.onSendToContact!(contact, 'ETH');
                },
              ),
              ListTile(
                leading: const AssetMark('BTC', size: 30),
                title: const Text('Enviar Bitcoin (BTC)'),
                subtitle: Text(shortAddress(contact.effectiveBtc)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  widget.onSendToContact!(contact, 'BTC');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    } else {
      Navigator.pop(context);
      widget.onSendToContact!(contact, contact.symbol);
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contactsTitle),
        actions: [
          IconButton(
            tooltip: l10n.showMyQr,
            icon: const Icon(Icons.qr_code_2),
            onPressed: _showMyContactQr,
          ),
          IconButton(
            tooltip: l10n.scanQrFriend,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQrFromCamera,
          ),
          if (widget.groupPurchases != null)
            IconButton(
              tooltip: l10n.groupPurchasesTitle,
              icon: const Icon(Icons.group_work_outlined),
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupPurchasesScreen(
                      controller: widget.groupPurchases!,
                      contacts: widget.contacts,
                      account: widget.account,
                    ),
                  ),
                );
              },
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addChoice,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.newContact),
      ),
      body: ValueListenableBuilder<List<WalletContact>>(
        valueListenable: _contacts,
        builder: (context, all, _) {
          final query = _search.text.trim().toLowerCase();
          final visible = all
              .where(_filter.accepts)
              .where(
                (contact) =>
                    query.isEmpty ||
                    contact.name.toLowerCase().contains(query) ||
                    (contact.username?.toLowerCase().contains(query) ??
                        false) ||
                    (contact.uniqueId?.toLowerCase().contains(query) ??
                        false) ||
                    contact.address.toLowerCase().contains(query),
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 960
                      ? 3
                      : (constraints.maxWidth >= 640 ? 2 : 1);

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth < 400 ? 12 : 16,
                          8,
                          constraints.maxWidth < 400 ? 12 : 16,
                          8,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card de Destaque para Meu QR Code
                              Card(
                                elevation: 0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: _showMyContactQr,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.qr_code_2,
                                          size: 28,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Mostrar Meu QR Code de Amigo',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                'Permita que amigos escaneiem seu cartão de contato',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SearchBar(
                                controller: _search,
                                hintText: l10n.searchContactsHint,
                                leading: const Icon(Icons.search),
                                elevation: const WidgetStatePropertyAll(0),
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(horizontal: 14),
                                ),
                                trailing: [
                                  if (_search.text.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Limpar busca',
                                      onPressed: _search.clear,
                                      icon: const Icon(Icons.close),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<_Filter>(
                                showSelectedIcon: false,
                                segments: [
                                  for (final filter in _Filter.values)
                                    ButtonSegment(
                                      value: filter,
                                      label: Text(filter.label),
                                    ),
                                ],
                                selected: {_filter},
                                onSelectionChanged: (value) =>
                                    setState(() => _filter = value.single),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: EmptyState(
                              icon: Icons.contacts_outlined,
                              title: all.isEmpty
                                  ? l10n.noContactsSaved
                                  : 'Nenhum contato encontrado',
                              message: all.isEmpty
                                  ? 'Adicione amigos pelo QR Code da carteira ou ID soberano para evitar transferências erradas e golpes.'
                                  : 'Ajuste a busca ou o filtro de rede.',
                            ),
                          ),
                        )
                      else if (crossAxisCount > 1)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            constraints.maxWidth < 400 ? 12 : 16,
                            4,
                            constraints.maxWidth < 400 ? 12 : 16,
                            96,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 125,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _contactTile(visible[index]),
                              childCount: visible.length,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            constraints.maxWidth < 400 ? 12 : 16,
                            4,
                            constraints.maxWidth < 400 ? 12 : 16,
                            96,
                          ),
                          sliver: SliverList.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _contactTile(visible[index]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Monta a linha do contato com o estado atual.
  Widget _contactTile(WalletContact contact) {
    final colors = Theme.of(context).colorScheme;
    final emojis = SecurityShieldService.visualEmojis(contact.address);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(contact.name, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.username != null) ...[
                            const SizedBox(width: 6),
                            UsernameBadge(contact.username!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (contact.uniqueId != null) ...[
                            UniqueIdBadge(contact.uniqueId!),
                            const SizedBox(width: 6),
                          ],
                          Text(emojis, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  enabled: !_busy,
                  onSelected: (action) {
                    if (action == 'copy') _copy(contact);
                    if (action == 'remove') _remove(contact);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy',
                      child: Text('Copiar endereço'),
                    ),
                    PopupMenuItem(value: 'remove', child: Text('Remover')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Linha de Ações Rápidas: Enviar, Cobrar, Compra Conjunta
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text('Enviar', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleSend(contact),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.request_quote_outlined, size: 16),
                    label: const Text('Cobrar', style: TextStyle(fontSize: 12)),
                    onPressed: () => _requestPaymentFromContact(contact),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.group_work_outlined, size: 16),
                    label: const Text('Racha', style: TextStyle(fontSize: 12)),
                    onPressed: () => _openGroupPurchasesWithContact(contact),
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

enum _ContactNetwork {
  ethereum('Ethereum · Sepolia e rede principal', 'ETH'),
  bitcoinTestnet('Bitcoin · Testnet4', 'BTC', BitcoinChain.testnet4),
  bitcoinMainnet('Bitcoin · rede principal', 'BTC', BitcoinChain.mainnet);

  /// Inicializa a configuração de agenda de contatos.
  const _ContactNetwork(this.label, this.symbol, [this.bitcoin]);
  final String label;
  final String symbol;
  final BitcoinChain? bitcoin;
}
