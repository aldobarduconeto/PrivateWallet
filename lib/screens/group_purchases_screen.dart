import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/contacts_controller.dart';
import '../controllers/group_purchase_controller.dart';
import '../models/group_purchase.dart';
import '../models/wallet_account.dart';
import '../models/wallet_contact.dart';
import '../widgets/wallet_widgets.dart';
import '../widgets/wallet_layout.dart';

/// Tela de Gestão de Compras Conjuntas (Racha Coletivo Soberano).
class GroupPurchasesScreen extends StatefulWidget {
  /// Inicializa [GroupPurchasesScreen] com os dados recebidos.
  const GroupPurchasesScreen({
    super.key,
    required this.controller,
    required this.contacts,
    this.account,
    this.initialContact,
    this.onPayShare,
  });

  final GroupPurchaseController controller;
  final ContactsController contacts;
  final WalletAccount? account;
  final WalletContact? initialContact;
  final void Function(GroupPurchaseMember member, GroupPurchase purchase)?
  onPayShare;

  /// Cria o estado local associado ao widget.
  @override
  State<GroupPurchasesScreen> createState() => _GroupPurchasesScreenState();
}

class _GroupPurchasesScreenState extends State<GroupPurchasesScreen> {
  final bool _busy = false;

  /// Retorna o controlador usado pela tela.
  GroupPurchaseController get _ctrl => widget.controller;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    if (!_ctrl.loaded) {
      _ctrl.load();
    }
    if (!widget.contacts.loaded) {
      widget.contacts.load().catchError((_) {});
    }

    if (widget.initialContact != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newPurchase(preselectedContact: widget.initialContact);
      });
    }
  }

  /// Publica a mudança para os observadores.
  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Abre o cadastro de uma compra conjunta.
  Future<void> _newPurchase({WalletContact? preselectedContact}) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final fiatCtrl = TextEditingController();
    var selectedAsset = widget.account?.symbol ?? 'ETH';
    final selectedContacts = <WalletContact>{?preselectedContact};
    var includeSelf = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final colors = Theme.of(ctx).colorScheme;
          final availableContacts = widget.contacts.value;

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
                        const Icon(Icons.group_work_outlined, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Nova Compra Conjunta',
                            style: TextStyle(
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título da Despesa',
                        hintText: 'ex: Churrasco de Sábado, Presente, Aluguel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Valor Total ($selectedAsset)',
                              hintText: '0.05',
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
                          selected: {selectedAsset},
                          onSelectionChanged: (val) =>
                              setModalState(() => selectedAsset = val.single),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fiatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Referência em R\$ ou US\$ (Opcional)',
                        hintText: 'ex: R\$ 350,00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Incluir minha própria cota no racha'),
                      subtitle: Text(
                        includeSelf
                            ? 'Você paga sua parte e arrecada a dos outros'
                            : 'Você é apenas o intermediário arrecadador',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: includeSelf,
                      onChanged: (val) =>
                          setModalState(() => includeSelf = val),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selecione os participantes da agenda:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (availableContacts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Nenhum contato na agenda. Você pode adicionar contatos pela tela de Contatos usando o ID deles.',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableContacts.length,
                          itemBuilder: (context, i) {
                            final contact = availableContacts[i];
                            final isSelected = selectedContacts.contains(
                              contact,
                            );
                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              title: Text(contact.name),
                              subtitle: Text(
                                contact.username ??
                                    contact.uniqueId ??
                                    shortAddress(contact.address),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onChanged: (checked) {
                                setModalState(() {
                                  if (checked == true) {
                                    selectedContacts.add(contact);
                                  } else {
                                    selectedContacts.remove(contact);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Criar Compra Conjunta'),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final rawAmount = double.tryParse(
                          amountCtrl.text.replaceAll(',', '.'),
                        );
                        if (title.isEmpty) {
                          _notify('Informe o título da despesa.');
                          return;
                        }
                        if (rawAmount == null || rawAmount <= 0) {
                          _notify('Informe um valor total válido.');
                          return;
                        }

                        final totalCount =
                            selectedContacts.length + (includeSelf ? 1 : 0);
                        if (totalCount <= 0) {
                          _notify('Selecione ao menos um participante.');
                          return;
                        }

                        final share = rawAmount / totalCount;
                        final members = <GroupPurchaseMember>[];

                        if (includeSelf && widget.account != null) {
                          final myAccount = widget.account!;
                          members.add(
                            GroupPurchaseMember(
                              id: 'self_${DateTime.now().millisecondsSinceEpoch}',
                              name: '${myAccount.name} (Você)',
                              username: myAccount.username,
                              uniqueId: myAccount.uniqueId,
                              address: myAccount.currentAddress,
                              shareAmount: share,
                              isPaid: true, // Organizador geralmente já pagou a despesa
                              paidAt: DateTime.now(),
                              isOrganizer: true,
                            ),
                          );
                        }

                        for (final c in selectedContacts) {
                          members.add(
                            GroupPurchaseMember(
                              id: 'contact_${c.address}_${DateTime.now().millisecondsSinceEpoch}',
                              name: c.name,
                              username: c.username,
                              uniqueId: c.uniqueId,
                              address: c.addressFor(
                                selectedAsset == 'BTC'
                                    ? widget.account?.bitcoinChain
                                    : null,
                              ),
                              shareAmount: share,
                              isPaid: false,
                            ),
                          );
                        }

                        final purchase = GroupPurchase(
                          id: 'gp_${DateTime.now().millisecondsSinceEpoch}',
                          title: title,
                          asset: selectedAsset,
                          totalAmount: rawAmount,
                          createdAt: DateTime.now(),
                          members: members,
                          fiatReference: fiatCtrl.text.trim().isNotEmpty
                              ? fiatCtrl.text.trim()
                              : null,
                        );

                        await _ctrl.create(purchase);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _notify('Compra conjunta "$title" criada com sucesso!');
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

  /// Compartilha `purchase summary` no fluxo de compras conjuntas.
  void _sharePurchaseSummary(GroupPurchase p) {
    final sb = StringBuffer();
    sb.writeln('🧾 *COMPRA CONJUNTA:* ${p.title}');
    sb.writeln(
      '💰 *Total:* ${p.totalAmount} ${p.asset}${p.fiatReference != null ? " (~ ${p.fiatReference})" : ""}',
    );
    sb.writeln(
      '📊 *Progresso:* ${p.paidMembersCount}/${p.totalMembers} pagos (${(p.progress * 100).toStringAsFixed(0)}%)',
    );
    sb.writeln('👥 *Participantes:*');
    for (final m in p.members) {
      final status = m.isPaid ? '✅ PAGO' : '⏳ PENDENTE';
      final handle = m.username ?? m.name;
      sb.writeln(
        '  $status $handle: ${m.shareAmount.toStringAsFixed(5)} ${p.asset}',
      );
    }
    if (widget.account != null) {
      sb.writeln('\n👉 *Para pagar sua cota, envie para:*');
      sb.writeln('Chave: ${widget.account!.currentAddress}');
      sb.writeln(
        'ID: ${widget.account!.uniqueId} (${widget.account!.username})',
      );
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    _notify(
      'Resumo da compra conjunta copiado para colar no WhatsApp/Telegram!',
    );
  }

  /// Solicita o pagamento do participante.
  void _requestMemberPayment(GroupPurchase p, GroupPurchaseMember m) {
    final myAccount = widget.account;
    final sb = StringBuffer();
    sb.writeln('Olá ${m.username ?? m.name}! 👋');
    sb.writeln('Aqui está a sua cota referente a: *${p.title}*');
    sb.writeln('Valor: *${m.shareAmount.toStringAsFixed(5)} ${p.asset}*');
    if (p.fiatReference != null) {
      sb.writeln('Referência do grupo: ${p.fiatReference}');
    }
    if (myAccount != null) {
      sb.writeln(
        '\nChave de recebimento (${p.asset}): ${myAccount.currentAddress}',
      );
      sb.writeln('ID Soberano: ${myAccount.uniqueId} (${myAccount.username})');
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    _notify('Mensagem de cobrança para ${m.name} copiada!');
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    return WalletScaffold(
      maxContentWidth: 1000,
      appBar: AppBar(
        title: const Text('Compras Conjuntas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => _ctrl.load(),
          ),
        ],
      ),
      floatingActionButton: WalletFloatingActionButton(
        onPressed: _busy ? null : () => _newPurchase(),
        icon: const Icon(Icons.add),
        label: 'Nova Compra Conjunta',
      ),
      body: ValueListenableBuilder<List<GroupPurchase>>(
        valueListenable: _ctrl,
        builder: (context, purchases, _) {
          if (purchases.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.group_work_outlined,
                  title: 'Nenhuma compra conjunta ativa',
                  message: 'Crie rachas coletivos com seus amigos para compras em grupo, almoços, viagens ou despesas compartilhadas.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: purchases.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) =>
                _buildPurchaseCard(purchases[index]),
          );
        },
      ),
    );
  }

  /// Monta `purchase card` no fluxo de compras conjuntas.
  Widget _buildPurchaseCard(GroupPurchase p) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: p.isSettled
              ? Colors.green.withValues(alpha: 0.5)
              : colors.outlineVariant,
          width: p.isSettled ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AssetMark(p.asset, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (p.fiatReference != null)
                        Text(
                          p.fiatReference!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (p.isSettled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CONCLUÍDO',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Text(
                    '${p.paidMembersCount}/${p.totalMembers} pagos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.progress,
                minHeight: 8,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  p.isSettled ? Colors.green : colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${p.totalAmount} ${p.asset}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Arrecadado: ${p.totalPaidAmount.toStringAsFixed(4)} ${p.asset}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Participantes e Cotas:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (final member in p.members) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: member.isPaid
                      ? Colors.green.withValues(alpha: 0.08)
                      : colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      member.isPaid ? Icons.check_circle : Icons.schedule,
                      size: 16,
                      color: member.isPaid ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: member.isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (member.username != null ||
                              member.uniqueId != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (member.username != null) ...[
                                  UsernameBadge(member.username!),
                                  const SizedBox(width: 4),
                                ],
                                if (member.uniqueId != null)
                                  UniqueIdBadge(member.uniqueId!),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${member.shareAmount.toStringAsFixed(4)} ${p.asset}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      tooltip: 'Opções do membro',
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        if (action == 'toggle') {
                          _ctrl.toggleMemberPaid(p.id, member.id);
                        } else if (action == 'charge') {
                          _requestMemberPayment(p, member);
                        } else if (action == 'pay') {
                          widget.onPayShare?.call(member, p);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            member.isPaid
                                ? 'Marcar como Pendente'
                                : 'Marcar como Pago',
                          ),
                        ),
                        if (!member.isPaid && !member.isOrganizer)
                          const PopupMenuItem(
                            value: 'charge',
                            child: Text('Copiar Cobrança da Cota'),
                          ),
                        if (!member.isPaid &&
                            member.isOrganizer &&
                            widget.onPayShare != null)
                          const PopupMenuItem(
                            value: 'pay',
                            child: Text('Pagar Minha Cota Agora'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Compartilhar Racha'),
                    onPressed: () => _sharePurchaseSummary(p),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Excluir compra conjunta',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir compra conjunta?'),
                        content: Text(
                          'Deseja excluir "${p.title}"? Esta ação não pode ser desfeita.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _ctrl.delete(p.id);
                      _notify('Compra conjunta removida.');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
