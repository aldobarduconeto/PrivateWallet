import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/wallet_controller.dart';
import '../models/wallet_account.dart';
import '../services/system/clipboard_guard_service.dart';
import '../widgets/wallet_widgets.dart';
import '../widgets/wallet_layout.dart';

class WalletAccountScreen extends StatefulWidget {
  /// Inicializa [WalletAccountScreen] com os dados recebidos.
  const WalletAccountScreen({
    super.key,
    required this.account,
    required this.controller,
    required this.onAccountUpdated,
    required this.onBackupRequested,
    required this.onExportQrRequested,
    required this.onRemoveRequested,
  });

  final WalletAccount account;
  final WalletController controller;
  final VoidCallback onAccountUpdated;
  final VoidCallback onBackupRequested;
  final VoidCallback onExportQrRequested;
  final VoidCallback onRemoveRequested;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletAccountScreen> createState() => _WalletAccountScreenState();
}

class _WalletAccountScreenState extends State<WalletAccountScreen> {
  late WalletAccount _account;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _account = widget.account;
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Abre a edição de o nome de usuário.
  Future<void> _editUsername() async {
    final ctrl = TextEditingController(
      text: _account.username.replaceAll('@', ''),
    );
    final newUsername = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar Nome de Usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha seu identificador público no Private Wallet.\nOutros usuários e contatos verão este nome nas transferências.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '@',
                labelText: 'Nome de usuário',
                hintText: 'ex: satoshibr, alice_eth',
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
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.length < 3) {
                return;
              }
              Navigator.pop(ctx, WalletAccount.sanitizeUsername(text));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newUsername != null && newUsername != _account.username) {
      final updated = _account.copyWith(username: newUsername);
      final accounts = [...widget.controller.accounts];
      final index = widget.controller.selected;
      accounts[index] = updated;
      await widget.controller.rename(_account.name); // triggers save
      // Atualiza diretamente no controller
      setState(() => _account = updated);
      widget.onAccountUpdated();
      _notify('Nome de usuário atualizado para $newUsername');
    }
  }

  /// Abre a edição de o nome da carteira.
  Future<void> _editWalletName() async {
    final ctrl = TextEditingController(text: _account.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Carteira'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome da Carteira',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _account.name) {
      await widget.controller.rename(newName);
      setState(() => _account = _account.copyWith(name: newName));
      widget.onAccountUpdated();
      _notify('Nome da carteira alterado para $newName');
    }
  }

  /// Copia o valor para a área de transferência com limpeza automática de segurança.
  void _copy(String text, String label) {
    ClipboardGuardService.copySensitive(
      context: context,
      text: text,
      label: label,
    );
  }

  /// Exibe o cartão do contato.
  void _showContactCardModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Meu Cartão de Contato Soberano',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Compartilhe com amigos para que eles adicionem você com 1 toque.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _account.contactSharePayload,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _account.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  UsernameBadge(_account.username),
                ],
              ),
              const SizedBox(height: 8),
              UniqueIdBadge(
                _account.uniqueId,
                fontSize: 13,
                onCopy: () => _copy(_account.uniqueId, 'Identificador PW-ID'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar ID'),
                      onPressed: () {
                        _copy(_account.uniqueId, 'Identificador PW-ID');
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Copiar Cartão'),
                      onPressed: () {
                        _copy(
                          _account.contactSharePayload,
                          'Cartão de contato soberano',
                        );
                        Navigator.pop(ctx);
                      },
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

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return WalletScaffold(
      appBar: AppBar(title: const Text('Gerenciamento da Conta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            // Card Principal de Perfil & Identidade
            BalanceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          _account.name.isNotEmpty
                              ? _account.name[0].toUpperCase()
                              : 'W',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _account.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _editUsername,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _account.username,
                                        style: const TextStyle(
                                          color: Colors.lightGreenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _account.isMultiCoin
                              ? 'Multi-Moeda · ETH + BTC'
                              : 'Moeda Única · ${_account.symbol}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _account.canSign
                              ? 'Autocustódia Soberana'
                              : 'Modo Leitura (Watch-Only)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card do Identificador Único (PW-ID) & Contato
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            color: colors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Identificador Único (PW-ID)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Seu código soberano exclusivo para conexões e compras',
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _account.uniqueId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Copiar PW-ID',
                            onPressed: () =>
                                _copy(_account.uniqueId, 'Identificador PW-ID'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _showContactCardModal,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Meu Cartão de Contato e QR Code'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Seção de Chaves Públicas e Endereços
            const WalletSectionTitle('Chaves Públicas e Endereços'),
            const SizedBox(height: 10),

            if (_account.isMultiCoin) ...[
              _AddressCard(
                title: 'Endereço Ethereum (ETH)',
                address: _account.ethAddress ?? _account.publicAddress,
                symbol: 'ETH',
                colors: colors,
                onCopy: () => _copy(
                  _account.ethAddress ?? _account.publicAddress,
                  'Endereço Ethereum',
                ),
              ),
              const SizedBox(height: 12),
              _AddressCard(
                title: 'Endereço Bitcoin SegWit (BTC)',
                address: _account.btcAddress ?? _account.publicAddress,
                symbol: 'BTC',
                colors: colors,
                onCopy: () => _copy(
                  _account.btcAddress ?? _account.publicAddress,
                  'Endereço Bitcoin',
                ),
              ),
            ] else ...[
              _AddressCard(
                title: 'Endereço Público (${_account.symbol})',
                address: _account.publicAddress,
                symbol: _account.symbol,
                colors: colors,
                onCopy: () => _copy(_account.publicAddress, 'Endereço'),
              ),
            ],

            const SizedBox(height: 24),

            // Ações de Gestão da Conta
            const WalletSectionTitle('Ações da Conta'),
            const SizedBox(height: 8),

            WalletPanel(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.alternate_email, color: colors.primary),
                    title: const Text('Alterar Nome de Usuário'),
                    subtitle: Text('Atualmente: ${_account.username}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editUsername,
                  ),
                  Divider(color: colors.outlineVariant),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, color: colors.primary),
                    title: const Text('Renomear Carteira'),
                    subtitle: Text('Atualmente: ${_account.name}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editWalletName,
                  ),
                  if (_account.canSign) ...[
                    Divider(color: colors.outlineVariant),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.key_outlined, color: colors.primary),
                      title: const Text('Chave de Recuperação / Backup'),
                      subtitle: const Text(
                        'Visualize sua chave privada com segurança',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: widget.onBackupRequested,
                    ),
                  ],
                  Divider(color: colors.outlineVariant),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.qr_code_2, color: colors.primary),
                    title: const Text('Sincronizar por QR Criptografado'),
                    subtitle: const Text(
                      'Transfira para outro aparelho via AES-256-GCM',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onExportQrRequested,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Zona de Remoção
            WalletPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
                title: const Text(
                  'Remover Carteira deste Aparelho',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Certifique-se de ter o backup antes de desconectar.',
                ),
                onTap: widget.onRemoveRequested,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _AddressCard extends StatelessWidget {
  /// Inicializa [_AddressCard] com os dados recebidos.
  const _AddressCard({
    required this.title,
    required this.address,
    required this.symbol,
    required this.colors,
    required this.onCopy,
  });

  final String title;
  final String address;
  final String symbol;
  final ColorScheme colors;
  final VoidCallback onCopy;

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetMark(symbol),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copiar Chave Pública',
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              address,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: address,
                size: 130,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
