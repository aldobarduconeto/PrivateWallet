import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/system/desktop_window_service.dart';
import '../services/system/header_command_service.dart';

/// Item de comando ou ferramenta pesquisável no Spotlight / Command Palette.
class _SearchItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color? iconColor;
  final List<String> keywords;
  final void Function(BuildContext context) execute;

  const _SearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.iconColor,
    required this.keywords,
    required this.execute,
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// Diálogo Spotlight / Paleta de Comandos aberta a partir da barra de pesquisa do cabeçalho.
class HeaderQuickSearchDialog extends StatefulWidget {
  const HeaderQuickSearchDialog({super.key});

  /// Abre a paleta de comandos no contexto fornecido.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const HeaderQuickSearchDialog(),
    );
  }

  @override
  State<HeaderQuickSearchDialog> createState() => _HeaderQuickSearchDialogState();
}

class _HeaderQuickSearchDialogState extends State<HeaderQuickSearchDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;
  String _query = '';

  late final List<_SearchItem> _allItems;

  @override
  void initState() {
    super.initState();
    _initItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initItems() {
    final cmd = HeaderCommandService.instance;
    _allItems = [
      // Operações & Cobrança
      _SearchItem(
        id: 'pos',
        title: 'Cobrar com QR',
        subtitle: 'Calcule o valor equivalente e receba pagamentos por QR Code',
        category: 'Cobrança & Vendas',
        icon: Icons.point_of_sale_outlined,
        iconColor: const Color(0xFF627EEA),
        keywords: ['pdv', 'cobrança', 'venda', 'loja', 'qr', 'receber', 'terminal', 'equivalência', 'pagamento'],
        execute: (ctx) => cmd.onOpenPos?.call(),
      ),
      _SearchItem(
        id: 'gas',
        title: 'Taxas de Envio',
        subtitle: 'Monitore o custo da rede para transferir no horário mais barato',
        category: 'Taxas & Custos',
        icon: Icons.speed,
        iconColor: Colors.deepOrange,
        keywords: ['gas', 'taxa', 'gwei', 'mempool', 'tarifa', 'rede', 'congestionamento', 'radar', 'custo'],
        execute: (ctx) => cmd.onOpenGasTracker?.call(),
      ),
      _SearchItem(
        id: 'finance',
        title: 'Guardar Dinheiro & Cofres',
        subtitle: 'Cofres, metas para seus objetivos e limites mensais',
        category: 'Gestão Financeira',
        icon: Icons.insights_rounded,
        iconColor: Colors.tealAccent.shade700,
        keywords: ['finanças', 'cofres', 'metas', 'orçamento', 'poupança', 'caixinha', 'guardar', 'conversor'],
        execute: (ctx) => cmd.onOpenFinance?.call(),
      ),
      _SearchItem(
        id: 'send',
        title: 'Enviar Dinheiro',
        subtitle: 'Transfira Bitcoin ou Ethereum com segurança pelo seu aparelho',
        category: 'Transferências',
        icon: Icons.arrow_upward_rounded,
        iconColor: Colors.amber.shade800,
        keywords: ['enviar', 'transferir', 'pagar', 'saque', 'remessa', 'btc', 'eth'],
        execute: (ctx) => cmd.onOpenSend?.call(),
      ),
      _SearchItem(
        id: 'receive',
        title: 'Receber Dinheiro',
        subtitle: 'Mostre seu QR Code ou copie seu endereço para receber depósitos',
        category: 'Transferências',
        icon: Icons.arrow_downward_rounded,
        iconColor: Colors.greenAccent.shade700,
        keywords: ['receber', 'depósito', 'qr code', 'chave', 'endereço', 'pagamento'],
        execute: (ctx) => cmd.onOpenReceive?.call(),
      ),
      _SearchItem(
        id: 'statement',
        title: 'Histórico de Movimentações',
        subtitle: 'Lista completa de envios, recebimentos e comprovantes',
        category: 'Histórico',
        icon: Icons.list_alt_rounded,
        iconColor: Colors.blueAccent,
        keywords: ['extrato', 'transações', 'movimentações', 'saldo', 'histórico', 'comprovante'],
        execute: (ctx) => cmd.onOpenStatement?.call(),
      ),
      _SearchItem(
        id: 'market',
        title: 'Cotações de Hoje',
        subtitle: 'Preços em tempo real de Bitcoin e Ethereum com alertas',
        category: 'Cotações',
        icon: Icons.trending_up,
        iconColor: const Color(0xFFF7931A),
        keywords: ['mercado', 'cotações', 'preço', 'bitcoin', 'ethereum', 'alertas', 'alta', 'baixa'],
        execute: (ctx) => cmd.onOpenMarket?.call(),
      ),
      _SearchItem(
        id: 'auto_debit',
        title: 'Pagamentos Automáticos',
        subtitle: 'Agendamentos e pagamentos recorrentes com lembretes',
        category: 'Gestão Financeira',
        icon: Icons.calendar_month_outlined,
        iconColor: Colors.indigoAccent,
        keywords: ['autodébito', 'recorrente', 'assinatura', 'mensalidade', 'plano', 'débito', 'agendamento'],
        execute: (ctx) => cmd.onOpenAutoDebits?.call(),
      ),
      _SearchItem(
        id: 'contacts',
        title: 'Amigos & Contatos',
        subtitle: 'Seus contatos frequentes e chaves salvas',
        category: 'Contatos',
        icon: Icons.contacts_outlined,
        iconColor: Colors.cyan,
        keywords: ['contatos', 'agenda', 'amigos', 'endereços', 'favoritos', 'nomes'],
        execute: (ctx) => cmd.onOpenContacts?.call(),
      ),

      // Segurança & Proteção
      _SearchItem(
        id: 'inspector',
        title: 'Checar Endereço Seguro',
        subtitle: 'Verifique se um endereço é seguro e evite enganos ou golpes',
        category: 'Segurança & Proteção',
        icon: Icons.manage_search_rounded,
        iconColor: Colors.lightBlueAccent,
        keywords: ['inspecionar', 'anti-golpe', 'auditoria', 'endereço', 'checksum', 'verificar', 'segurança'],
        execute: (ctx) => cmd.onOpenAddressInspector?.call(),
      ),
      _SearchItem(
        id: 'stealth',
        title: 'Proteção de Tela & Privacidade',
        subtitle: 'Oculte saldos em locais públicos e ative senha de emergência',
        category: 'Segurança & Proteção',
        icon: Icons.shield_outlined,
        iconColor: Colors.purpleAccent,
        keywords: ['privacidade', 'camuflagem', 'isca', 'decoy', 'coação', 'emergência', 'sigilo', 'proteção'],
        execute: (ctx) => cmd.onOpenPrivacyStealth?.call(),
      ),
      _SearchItem(
        id: 'clear_clipboard',
        title: 'Limpar Texto Copiado',
        subtitle: 'Apague chaves e textos sensíveis da memória do aparelho agora',
        category: 'Segurança & Proteção',
        icon: Icons.cleaning_services_outlined,
        iconColor: Colors.pinkAccent,
        keywords: ['clipboard', 'limpar', 'área de transferência', 'memória', 'chaves', 'segurança', 'purgar'],
        execute: (ctx) => cmd.cleanClipboard(ctx),
      ),
      _SearchItem(
        id: 'toggle_privacy',
        title: 'Ocultar ou Mostrar Saldos',
        subtitle: 'Mascara os valores na tela (••••••) para proteger sua privacidade',
        category: 'Segurança & Proteção',
        icon: Icons.visibility_off_outlined,
        iconColor: Colors.blueGrey,
        keywords: ['ocultar', 'esconder', 'saldo', 'discreto', 'visibilidade', 'privacidade'],
        execute: (ctx) => cmd.toggleBalancePrivacy(),
      ),
      _SearchItem(
        id: 'settings',
        title: 'Configurações',
        subtitle: 'Moeda padrão (Real, Dólar, Euro), segurança e aparência',
        category: 'Configurações',
        icon: Icons.settings_outlined,
        iconColor: Colors.grey,
        keywords: ['configurações', 'moeda base', 'brl', 'usd', 'eur', 'rede', 'pin', 'senha', 'tema'],
        execute: (ctx) => cmd.onOpenSettings?.call(),
      ),
    ];
  }

  List<_SearchItem> get _filteredItems {
    return _allItems.where((item) => item.matches(_query)).toList();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final items = _filteredItems;
    if (items.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < items.length) {
        _executeItem(items[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _executeItem(_SearchItem item) {
    Navigator.pop(context);
    item.execute(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _filteredItems;

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.isEmpty ? 0 : items.length - 1;
    }

    final dialogBg = isDark ? const Color(0xFF141926) : const Color(0xFFF9FAFD);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    final isDesktop = DesktopWindowService.isDesktop;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 540),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Campo de pesquisa no topo
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar ferramentas, recursos ou ações...',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (text) {
                            setState(() {
                              _query = text;
                              _selectedIndex = 0;
                            });
                          },
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar texto',
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _selectedIndex = 0;
                            });
                          },
                        ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isDesktop
                              ? Text(
                                  'ESC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                )
                              : Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: borderColor),

                // Lista de resultados filtrados
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Nenhuma ferramenta encontrada para "$_query"',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = index == _selectedIndex;

                            return InkWell(
                              onTap: () => _executeItem(item),
                              hoverColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: (item.iconColor ?? theme.colorScheme.primary)
                                            .withValues(alpha: isDark ? 0.18 : 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 18,
                                        color: item.iconColor ?? theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13.5,
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.category,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.subdirectory_arrow_left_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                Divider(height: 1, color: borderColor),

                // Rodapé com dicas de atalho
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isDesktop)
                        Row(
                          children: [
                            _shortcutPill('↑↓', 'Navegar', theme, isDark),
                            const SizedBox(width: 10),
                            _shortcutPill('↵ Enter', 'Abrir', theme, isDark),
                            const SizedBox(width: 10),
                            _shortcutPill('ESC', 'Fechar', theme, isDark),
                          ],
                        )
                      else
                        Text(
                          'Toque em um item para abrir',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      Text(
                        'Private Wallet Spotlight',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcutPill(String keyLabel, String actionLabel, ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          actionLabel,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
