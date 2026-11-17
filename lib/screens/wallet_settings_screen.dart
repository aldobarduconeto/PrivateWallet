import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/wallet_controller.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import '../models/app_contrast_theme.dart';
import '../models/networks.dart';
import '../models/wallet_account.dart';
import '../models/wallet_preferences.dart';
import '../models/fiat_currency.dart';
import '../services/fiat_exchange_service.dart';
import '../services/system/auth_protection_service.dart';
import 'wallet_account_screen.dart';
import 'welcome_onboarding_screen.dart';

enum SettingsAction {
  create,
  importKey,
  watch,
  rename,
  backup,
  exportQr,
  importQr,
  mirrorAccounts,
  market,
  pos,
  inspector,
  gasTracker,
  privacyStealth,
  history,
  statement,
  finance,
  autoDebit,
  manageAccount,
  contacts,
  remove,
}

const _themeLabels = {
  ThemeMode.system: 'Do sistema',
  ThemeMode.light: 'Claro',
  ThemeMode.dark: 'Escuro',
};

class WalletSettingsScreen extends StatefulWidget {
  /// Inicializa [WalletSettingsScreen] com os dados recebidos.
  const WalletSettingsScreen({
    super.key,
    required this.preferences,
    required this.save,
    required this.walletName,
    required this.canSign,
    required this.canManageWallets,
    this.walletAccount,
    this.walletController,
    this.onAccountUpdated,
  });

  final ValueListenable<WalletPreferences> preferences;
  final Future<void> Function(WalletPreferences) save;
  final String? walletName;
  final bool canSign;
  final bool canManageWallets;
  final WalletAccount? walletAccount;
  final WalletController? walletController;
  final VoidCallback? onAccountUpdated;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsPageState();
}

class _WalletSettingsPageState extends State<WalletSettingsScreen> {
  bool _saving = false;
  bool _hasMasterPass = false;
  bool _hasDuressPass = false;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _checkSecurityState();
  }

  /// Verifica o estado das proteções de segurança soberanas.
  Future<void> _checkSecurityState() async {
    final hasPass = await AuthProtectionService.hasMasterPassword();
    final hasDuress = await AuthProtectionService.hasDuressPassword();
    if (mounted) {
      setState(() {
        _hasMasterPass = hasPass;
        _hasDuressPass = hasDuress;
      });
    }
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> _save(WalletPreferences values) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.save(values);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a preferência.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Exibe as opções e retorna a selecionada ao fechar o diálogo.
  Future<T?> _choose<T extends Object>(
    String title,
    Map<T, String> options,
    T current,
  ) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final entry in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Row(
              children: [
                Icon(
                  entry.key == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(entry.value)),
              ],
            ),
          ),
      ],
    ),
  );

  /// Abre a busca por código e salva a moeda de comparação selecionada.
  Future<void> _chooseFiatCurrency() async {
    final rates = FiatExchangeService.instance.rates();
    var query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Definir Moeda Base de Referência'),
          content: SizedBox(
            width: 360,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escolha a moeda governamental padrão (ex: BRL, USD, EUR). Ela será usada para estimativas de saldo no painel e para o cálculo do valor equivalente na Cobrança PDV.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar pelo código da moeda',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => query = value.trim().toUpperCase()),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<Map<String, double>>(
                    future: rates,
                    builder: (context, snapshot) {
                      final codes = {
                        ...FiatCurrency.supportedCodes,
                        ...?snapshot.data?.keys,
                      }.where((code) => code.contains(query)).toList()..sort();
                      if (codes.isEmpty) {
                        return const Center(
                          child: Text('Nenhuma moeda encontrada'),
                        );
                      }
                      return ListView.builder(
                        itemCount: codes.length,
                        itemBuilder: (context, index) {
                          final code = codes[index];
                          return ListTile(
                            title: Text(code),
                            selected:
                                code ==
                                widget.preferences.value.fiatCurrency.code,
                            onTap: () => Navigator.pop(context, code),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _save(
        widget.preferences.value.copyWith(fiatCurrency: FiatCurrency(selected)),
      );
    }
  }

  /// Abre a seleção de o idioma.
  Future<void> _chooseLanguage() async {
    final current = widget.preferences.value.language;
    var query = '';
    final lang = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final languages = AppLanguage.values
              .where(
                (language) =>
                    language.label.toLowerCase().contains(query) ||
                    language.code.contains(query),
              )
              .toList();
          return AlertDialog(
            title: const Text('Idioma / Language'),
            content: SizedBox(
              width: 360,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar / Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (text) =>
                        setDialogState(() => query = text.trim().toLowerCase()),
                  ),
                  Expanded(
                    child: languages.isEmpty
                        ? const Center(
                            child: Text('Nenhum idioma / No languages'),
                          )
                        : ListView.builder(
                            itemCount: languages.length,
                            itemBuilder: (context, index) {
                              final language = languages[index];
                              return ListTile(
                                title: Text(language.label),
                                subtitle: language.locale == null
                                    ? null
                                    : Text(language.code),
                                selected: language.code == current.code,
                                onTap: () => Navigator.pop(context, language),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (lang != null && mounted) {
      await _save(widget.preferences.value.copyWith(language: lang));
    }
  }

  /// Abre a seleção de o tema.
  Future<void> _chooseTheme() async {
    final theme = await _choose(
      'Tema do aplicativo',
      _themeLabels,
      widget.preferences.value.theme,
    );
    if (theme != null) {
      await _save(widget.preferences.value.copyWith(theme: theme));
    }
  }

  /// Abre a seleção de o tema de contraste.
  Future<void> _chooseContrastTheme() async {
    final contrast = await _choose('Cor de destaque e contraste', {
      for (final item in AppContrastTheme.values) item: item.label,
    }, widget.preferences.value.contrastTheme);
    if (contrast != null) {
      await _save(widget.preferences.value.copyWith(contrastTheme: contrast));
    }
  }

  /// Abre a seleção de a rede.
  Future<void> _chooseNetwork() async {
    final network = await _choose('Rede inicial do Ethereum', {
      for (final item in Network.values) item: item.label,
    }, widget.preferences.value.ethereumNetwork);
    if (network != null) {
      await _save(widget.preferences.value.copyWith(ethereumNetwork: network));
    }
  }

  /// Alterna `biometrics` no fluxo de configurações.
  Future<void> _toggleBiometrics(bool enable) async {
    if (enable) {
      final success = await AuthProtectionService.authenticateBiometrics(
        title: 'Ativar Acesso por Biometria',
        subtitle:
            'Confirme sua biometria ou Face ID para habilitar esta proteção',
      );
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha na validação biométrica.')),
          );
        }
        return;
      }
    }
    await _save(
      widget.preferences.value.copyWith(biometricAuthEnabled: enable),
    );
  }

  /// Gerencia o PIN ou Senha Mestra Universal (sem e-mail/SMS).
  Future<void> _manageMasterPassword() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            _hasMasterPass
                ? 'Alterar PIN / Senha Mestra'
                : 'Definir PIN / Senha Mestra Local',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Este PIN/senha criptográfico é armazenado localmente no cofre seguro do seu dispositivo.\n\n'
                  'Ele opera sem e-mail ou telefone (imune a ataques de SIM Swap e vazamento de banco de dados). Guarde-o com segurança.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Novo PIN ou Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar PIN ou Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (_hasMasterPass)
              TextButton(
                onPressed: () async {
                  await AuthProtectionService.removeMasterPassword();
                  await _save(
                    widget.preferences.value.copyWith(
                      desktopPasswordEnabled: false,
                    ),
                  );
                  await _checkSecurityState();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'Remover PIN/Senha',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final pass = passController.text.trim();
                final confirm = confirmController.text.trim();
                if (pass.length < 4) {
                  setDlgState(
                    () => error = 'O PIN ou senha deve ter pelo menos 4 caracteres.',
                  );
                  return;
                }
                if (pass != confirm) {
                  setDlgState(() => error = 'As senhas não coincidem.');
                  return;
                }
                await AuthProtectionService.setMasterPassword(pass);
                await _save(
                  widget.preferences.value.copyWith(
                    desktopPasswordEnabled: true,
                  ),
                );
                await _checkSecurityState();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Gerencia o PIN de Coação (Duress PIN) para defesa contra ameaças físicas.
  Future<void> _manageDuressPassword() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            _hasDuressPass
                ? 'Alterar PIN de Coação'
                : 'Definir PIN de Coação (Duress PIN)',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'O PIN de Coação é uma defesa contra ameaças físicas (ex: coação ou chantagem presencial).\n\n'
                  'Se você for forçado a abrir o app e digitar este PIN na tela de bloqueio, o aplicativo desbloqueia silenciosamente no MODO ISCA (Decoy Mode) com fundos demonstrativos e sem dar sinal de alerta.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Novo PIN de Coação',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar PIN de Coação',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (_hasDuressPass)
              TextButton(
                onPressed: () async {
                  await AuthProtectionService.removeDuressPassword();
                  await _checkSecurityState();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'Remover PIN de Coação',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final pass = passController.text.trim();
                final confirm = confirmController.text.trim();
                if (pass.length < 4) {
                  setDlgState(
                    () => error = 'O PIN deve ter pelo menos 4 dígitos.',
                  );
                  return;
                }
                if (pass != confirm) {
                  setDlgState(() => error = 'Os PINs não coincidem.');
                  return;
                }
                try {
                  await AuthProtectionService.setDuressPassword(pass);
                  await _checkSecurityState();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDlgState(
                    () => error = e.toString().replaceAll('FormatException: ', ''),
                  );
                }
              },
              child: const Text('Salvar PIN de Coação'),
            ),
          ],
        ),
      ),
    );
  }

  /// Explica a soberania da carteira e a eliminação de e-mail e telefone.
  Future<void> _whyNoEmailDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green),
            SizedBox(width: 8),
            Text('Segurança Soberana Cripto'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Por que o PrivateWallet NÃO usa e-mail nem telefone?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 10),
              Text(
                '1. Ataques de SIM Swap:\n'
                'Criminosos clonam números de telefone em operadoras para roubar carteiras protegidas por SMS.\n\n'
                '2. Vazamentos em Bancos de Dados Centrais:\n'
                'Serviços que guardam e-mails e senhas em servidores são alvos constantes de vazamentos que expõem os usuários a hackers.\n\n'
                '3. Autocustódia Matemática Pura:\n'
                'Em criptomoedas reais, a posse de fundos é comprovada matematicamente pela posse da sua chave privada ou frase mnemônica.\n\n'
                '4. Privacidade Total sem KYC:\n'
                'Você não precisa informar nenhum dado pessoal para usar sua carteira. Suas chaves residem exclusivamente neste aparelho.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  /// Abre `account management` no fluxo de configurações.
  void _openAccountManagement() {
    if (widget.walletAccount == null || widget.walletController == null) {
      Navigator.pop(context, SettingsAction.manageAccount);
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletAccountScreen(
          account: widget.walletAccount!,
          controller: widget.walletController!,
          onAccountUpdated: () {
            widget.onAccountUpdated?.call();
            setState(() {});
          },
          onBackupRequested: () =>
              Navigator.pop(context, SettingsAction.backup),
          onExportQrRequested: () =>
              Navigator.pop(context, SettingsAction.exportQr),
          onRemoveRequested: () =>
              Navigator.pop(context, SettingsAction.remove),
        ),
      ),
    );
  }

  /// Abre as informações de ajuda e privacidade.
  Future<void> _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ajuda e privacidade'),
      content: const SingleChildScrollView(
        child: Text(
          'O Private Wallet opera em autocustódia soberana:\n\n'
          '• Chaves privadas geradas e mantidas apenas no seu dispositivo.\n'
          '• Sem cadastro, sem telemetria e sem contas externas.\n'
          '• O nome de usuário (@username) é sua identidade pública no app.\n'
          '• Proteção biométrica e senha de computador para impedir acessos indevidos.\n\n'
          'Faça backup das suas chaves em local seguro.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );

  /// Abre as informações do aplicativo.
  Future<void> _about() async {
    final info = await PackageInfo.fromPlatform().catchError(
      (Object _) => PackageInfo(
        appName: 'Private Wallet',
        packageName: '',
        version: '1.0.0',
        buildNumber: '1',
      ),
    );
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: info.appName,
      applicationVersion: '${info.version} (${info.buildNumber})',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('assets/wallet_icon.png', width: 44, height: 44),
      ),
      children: const [
        Text(
          'Carteira de autocustódia para Ethereum e Bitcoin com suporte multi-moeda e proteção biométrica.',
        ),
      ],
    );
  }

  /// Agrupa as opções de uma seção da tela.
  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.1,
          ),
        ),
      ),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ],
  );

  /// Monta uma opção de configurações com ícone, texto e ação.
  Widget _link(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? detail,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: detail == null ? null : Text(detail),
    trailing: const Icon(Icons.chevron_right),
    onTap: _saving ? null : onTap,
  );

  /// Monta o atalho de acesso à carteira nas configurações.
  Widget _walletLink(IconData icon, String title, SettingsAction action) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: _saving ? null : () => Navigator.pop(context, action),
      );

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final account = widget.walletAccount;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ValueListenableBuilder<WalletPreferences>(
        valueListenable: widget.preferences,
        builder: (context, values, _) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8).copyWith(bottom: 40),
                children: [
              // ==========================================
              // SEÇÃO DEDICADA: GERENCIAMENTO DA CONTA & PERFIL
              // ==========================================
              if (account != null)
                _section('Minha Conta & Perfil', [
                  ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primaryContainer,
                      child: Text(
                        account.name.isNotEmpty
                            ? account.name[0].toUpperCase()
                            : 'W',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          account.username,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.isMultiCoin
                              ? 'Multi-Moeda · ETH + BTC'
                              : account.symbol,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _openAccountManagement,
                      child: const Text('Gerenciar'),
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  _link(
                    Icons.badge_outlined,
                    'Exibir Informações da Conta e Chaves',
                    _openAccountManagement,
                    detail: 'Chaves públicas, endereços on-chain e alteração de @username.',
                  ),
                ]),

              // ==========================================
              // SEÇÃO: SEGURANÇA SOBERANA (SEM E-MAIL / SEM TELEFONE)
              // ==========================================
              _section('Segurança Soberana (Sem E-mail / Sem Telefone)', [
                ListTile(
                  leading: const Icon(Icons.password_outlined, color: Colors.blue),
                  title: const Text('PIN / Senha Mestra Local'),
                  subtitle: Text(
                    _hasMasterPass
                        ? 'PIN/Senha ativa · toque para alterar ou remover'
                        : 'Nenhum PIN configurado · toque para proteger seu cofre',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _manageMasterPassword,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_clock_outlined),
                  title: const Text('Exigir PIN / Senha ao Abrir o App'),
                  subtitle: const Text(
                    'Trava o aplicativo ao iniciar até digitar a senha local.',
                  ),
                  value: values.desktopPasswordEnabled && _hasMasterPass,
                  onChanged: (!_hasMasterPass || _saving)
                      ? null
                      : (enabled) => _save(
                          values.copyWith(desktopPasswordEnabled: enabled),
                        ),
                ),
                if (AuthProtectionService.isMobile) ...[
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Acesso por Biometria / Face ID'),
                    subtitle: const Text(
                      'Desbloqueio rápido por biometria mantendo o PIN como segurança.',
                    ),
                    value: values.biometricAuthEnabled,
                    onChanged: _saving ? null : _toggleBiometrics,
                  ),
                ],
                SwitchListTile(
                  secondary: const Icon(Icons.phonelink_lock),
                  title: const Text('Bloquear ao Minimizar / Segundo Plano'),
                  subtitle: const Text(
                    'Requer autenticação imediatamente ao retornar para o app.',
                  ),
                  value: values.lockOnBackground,
                  onChanged: _saving
                      ? null
                      : (enabled) =>
                            _save(values.copyWith(lockOnBackground: enabled)),
                ),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.amber),
                  title: const Text('PIN de Coação (Duress PIN)'),
                  subtitle: Text(
                    _hasDuressPass
                        ? 'Ativo · abre a carteira isca silenciosamente sob ameaça'
                        : 'Configurar PIN falso para situações de coação física',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _manageDuressPassword,
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.green),
                  title: const Text('Proteção Anti-Força Bruta'),
                  subtitle: const Text(
                    'Delay progressivo automático após tentativas incorretas.',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ativo',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.content_paste_go, color: Colors.green),
                  title: const Text('Limpeza de Clipboard (45s)'),
                  subtitle: const Text(
                    'Apaga chaves e dados sensíveis da área de transferência.',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Ativo',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
                  title: const Text('Por que NÃO usamos e-mail ou telefone?'),
                  subtitle: const Text(
                    'Entenda por que autocustódia elimina SIM Swap, vazamentos e phishing.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _whyNoEmailDialog,
                ),
              ]),

              // ==========================================
              // SEÇÃO: IDIOMA DO APLICATIVO
              // ==========================================
              _section('Idioma / Language', [
                _link(
                  Icons.language_outlined,
                  context.l10n.appLanguage,
                  _chooseLanguage,
                  detail: values.language.label,
                ),
              ]),

              // ==========================================
              // SEÇÃO: APARÊNCIA & CONTRASTE
              // ==========================================
              _section('Aparência', [
                _link(
                  Icons.brightness_medium_outlined,
                  'Tema do aplicativo',
                  _chooseTheme,
                  detail: _themeLabels[values.theme],
                ),
                _link(
                  Icons.palette_outlined,
                  'Cor de destaque e contraste',
                  _chooseContrastTheme,
                  detail: values.contrastTheme.label,
                ),
              ]),

              // ==========================================
              // SEÇÃO: PRIVACIDADE DO SALDO & MOEDA BASE
              // ==========================================
              _section('Saldo & Moeda Base de Referência', [
                _link(
                  Icons.currency_exchange,
                  'Moeda Base de Comparação & Cobrança',
                  _chooseFiatCurrency,
                  detail:
                      '${values.fiatCurrency.code} · Moeda padrão do painel e do modo PDV',
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: Text(context.l10n.hideBalanceOnOpen),
                  subtitle: const Text(
                    'Começa com o valor oculto ao reiniciar o app.',
                  ),
                  value: values.hideBalanceAtStartup,
                  onChanged: _saving
                      ? null
                      : (enabled) => _save(
                          values.copyWith(hideBalanceAtStartup: enabled),
                        ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on),
                  title: Text(context.l10n.hideBalanceInBackground),
                  subtitle: const Text(
                    'Oculta os valores na visualização de multitarefa.',
                  ),
                  value: values.hideBalanceInBackground,
                  onChanged: _saving
                      ? null
                      : (enabled) => _save(
                          values.copyWith(hideBalanceInBackground: enabled),
                        ),
                ),
              ]),

              // ==========================================
              // SEÇÃO: REDES ON-CHAIN
              // ==========================================
              _section('Redes', [
                _link(
                  Icons.hub_outlined,
                  'Rede inicial do Ethereum',
                  _chooseNetwork,
                  detail:
                      '${values.ethereumNetwork.label} · aplicada ao reabrir o app',
                ),
                const ListTile(
                  leading: Icon(Icons.currency_bitcoin),
                  title: Text('Rede do Bitcoin'),
                  subtitle: Text(
                    'Definida ao criar ou importar cada carteira.',
                  ),
                ),
              ]),

              // ==========================================
              // SEÇÃO: CARTEIRAS
              // ==========================================
              if (widget.canManageWallets)
                _section('Carteiras & Operações', [
                  _walletLink(
                    Icons.add,
                    'Criar carteira',
                    SettingsAction.create,
                  ),
                  _walletLink(
                    Icons.key_outlined,
                    'Importar chave privada',
                    SettingsAction.importKey,
                  ),
                  _walletLink(
                    Icons.visibility_outlined,
                    'Acompanhar endereço',
                    SettingsAction.watch,
                  ),
                  _walletLink(
                    Icons.qr_code_scanner,
                    'Importar por QR',
                    SettingsAction.importQr,
                  ),
                  _walletLink(
                    Icons.copy_all_rounded,
                    'Adicionar cold wallet por QR',
                    SettingsAction.mirrorAccounts,
                  ),
                  _walletLink(
                    Icons.contacts_outlined,
                    'Contatos',
                    SettingsAction.contacts,
                  ),
                  if (widget.walletName != null) ...[
                    _walletLink(
                      Icons.manage_accounts_outlined,
                      'Gerenciar Carteira Ativa',
                      SettingsAction.manageAccount,
                    ),
                    _walletLink(
                      Icons.qr_code_2,
                      'Sincronizar por QR',
                      SettingsAction.exportQr,
                    ),
                    if (widget.canSign)
                      _walletLink(
                        Icons.lock_outline,
                        'Chave de recuperação',
                        SettingsAction.backup,
                      ),
                    _walletLink(
                      Icons.receipt_long_outlined,
                      'Histórico de envios',
                      SettingsAction.history,
                    ),
                    _walletLink(
                      Icons.list_alt_rounded,
                      'Extrato de movimentações',
                      SettingsAction.statement,
                    ),
                    _walletLink(
                      Icons.insights_rounded,
                      'Finanças, Conversor e Metas',
                      SettingsAction.finance,
                    ),
                    _walletLink(
                      Icons.trending_up,
                      'Mercado & Alertas de Preço',
                      SettingsAction.market,
                    ),
                    _walletLink(
                      Icons.point_of_sale_outlined,
                      'Cobrança Rápida & PDV',
                      SettingsAction.pos,
                    ),
                    _walletLink(
                      Icons.security,
                      'Inspetor Anti-Golpe de Endereços',
                      SettingsAction.inspector,
                    ),
                    _walletLink(
                      Icons.speed,
                      'Otimizador de Gas & Mempool',
                      SettingsAction.gasTracker,
                    ),
                    _walletLink(
                      Icons.shield_outlined,
                      'Central de Privacidade & Camuflagem',
                      SettingsAction.privacyStealth,
                    ),
                    _walletLink(
                      Icons.autorenew,
                      'Débito Automático (Assinaturas & Aluguel)',
                      SettingsAction.autoDebit,
                    ),
                    _walletLink(
                      Icons.remove_circle_outline,
                      'Remover carteira ativa',
                      SettingsAction.remove,
                    ),
                  ],
                ]),

              // ==========================================
              // SEÇÃO: APLICATIVO & PERMISSÕES
              // ==========================================
              _section('Aplicativo', [
                _link(
                  Icons.verified_user_outlined,
                  'Boas-vindas e Permissões do Sistema',
                  () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WelcomeOnboardingScreen(
                        accountName: widget.walletName,
                      ),
                    ),
                  ),
                  detail: 'Revise os recursos ativos: segundo plano, armazenamento, notificações e conectividade.',
                ),
                _link(Icons.help_outline, 'Ajuda e privacidade', _help),
                _link(Icons.info_outline, 'Sobre e licenças', _about),
                _link(
                  Icons.restart_alt,
                  'Restaurar preferências',
                  () async {
                    await _save(const WalletPreferences());
                  },
                  detail: 'Volta ao tema do sistema, à Sepolia e às opções padrão de saldo.',
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}
