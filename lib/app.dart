import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/preferences_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/wallet_home_screen.dart';
import 'services/system/desktop_window_service.dart';
import 'theme/wallet_theme.dart';
import 'widgets/desktop_title_bar.dart';
import 'widgets/header_quick_search_dialog.dart';

class PrivateWalletApp extends StatefulWidget {
  /// Inicializa [PrivateWalletApp] com os dados recebidos.
  const PrivateWalletApp({super.key});

  /// Chave de navegação global para acesso a modais e rotas pelo cabeçalho desktop.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Cria o estado local associado ao widget.
  @override
  State<PrivateWalletApp> createState() => _PrivateWalletAppState();
}

class _PrivateWalletAppState extends State<PrivateWalletApp> {
  final _preferences = PreferencesController();
  bool _loadingPreferences = true;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Carrega as preferências antes de liberar a tela inicial.
  Future<void> _loadPreferences() async {
    await _preferences.load();
    if (mounted) setState(() => _loadingPreferences = false);
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _preferences,
    builder: (context, preferences, _) {
      final lightTheme = walletTheme(
        Brightness.light,
        contrastTheme: preferences.contrastTheme,
      );
      final darkTheme = walletTheme(
        Brightness.dark,
        contrastTheme: preferences.contrastTheme,
      );

      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            final ctx = PrivateWalletApp.navigatorKey.currentContext;
            if (ctx != null) HeaderQuickSearchDialog.show(ctx);
          },
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
            final ctx = PrivateWalletApp.navigatorKey.currentContext;
            if (ctx != null) HeaderQuickSearchDialog.show(ctx);
          },
        },
        child: MaterialApp(
          navigatorKey: PrivateWalletApp.navigatorKey,
          title: 'Private Wallet',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: preferences.theme,
          locale: preferences.language.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            DesktopWindowService.updateTitleBar(isDark ? darkTheme : lightTheme);

            // Ajusta o estilo de sobreposição nativa dos sistemas móveis (Android & iOS) para edge-to-edge
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
            );

            final content = child ?? const SizedBox.shrink();
            return Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Column(
                      children: [
                        const DesktopTitleBar(),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          home: _loadingPreferences
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : WalletHome(
                  preferences: _preferences,
                  savePreferences: _preferences.save,
                ),
        ),
      );
    },
  );
}
