import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:private_wallet/controllers/auto_debit_controller.dart';
import 'package:private_wallet/controllers/contacts_controller.dart';
import 'package:private_wallet/controllers/goals_controller.dart';
import 'package:private_wallet/controllers/group_purchase_controller.dart';
import 'package:private_wallet/controllers/preferences_controller.dart';
import 'package:private_wallet/controllers/statement_controller.dart';
import 'package:private_wallet/controllers/wallet_controller.dart';
import 'package:private_wallet/l10n/app_localizations.dart';
import 'package:private_wallet/models/chain_movement.dart';
import 'package:private_wallet/models/networks.dart';
import 'package:private_wallet/models/wallet_account.dart';
import 'package:private_wallet/screens/app_lock_screen.dart';
import 'package:private_wallet/screens/crypto_market_screen.dart';
import 'package:private_wallet/screens/crypto_pos_screen.dart';
import 'package:private_wallet/screens/gas_tracker_screen.dart';
import 'package:private_wallet/screens/group_purchases_screen.dart';
import 'package:private_wallet/screens/privacy_stealth_screen.dart';
import 'package:private_wallet/screens/wallet_account_screen.dart';
import 'package:private_wallet/screens/wallet_activity_screen.dart';
import 'package:private_wallet/screens/wallet_auto_debit_screen.dart';
import 'package:private_wallet/screens/wallet_contacts_screen.dart';
import 'package:private_wallet/screens/wallet_finance_screen.dart';
import 'package:private_wallet/screens/wallet_home_screen.dart';
import 'package:private_wallet/screens/wallet_settings_screen.dart';
import 'package:private_wallet/screens/wallet_statement_screen.dart';
import 'package:private_wallet/screens/wallet_sync_screen.dart';
import 'package:private_wallet/screens/welcome_onboarding_screen.dart';
import 'package:private_wallet/theme/wallet_theme.dart';

void main() {
  testWidgets('screens fit phone, tablet and desktop viewports', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final account = WalletAccount.watch(
      'Carteira de teste',
      '0x0000000000000000000000000000000000001234',
    );
    final explorer = Uri.https('example.com');
    final contacts = ContactsController();
    final purchases = GroupPurchaseController();
    final autoDebits = AutoDebitController();
    final goals = GoalsController();
    final preferences = PreferencesController();
    final wallet = WalletController(Network.sepolia);
    final statement = StatementController(
      fetch: (_) async => (items: <ChainMovement>[], cursor: null),
      localSends: () async => [],
    );
    addTearDown(contacts.dispose);
    addTearDown(purchases.dispose);
    addTearDown(autoDebits.dispose);
    addTearDown(goals.dispose);
    addTearDown(preferences.dispose);
    addTearDown(statement.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final routes = [
      AppLockScreen(onUnlocked: () {}),
      const CryptoMarketScreen(),
      CryptoPosScreen(account: account),
      const GasTrackerScreen(),
      GroupPurchasesScreen(controller: purchases, contacts: contacts),
      PrivacyStealthScreen(
        account: account,
        hasBiometrics: false,
        lockOnBackground: false,
      ),
      WalletAccountScreen(
        account: account,
        controller: wallet,
        onAccountUpdated: () {},
        onBackupRequested: () {},
        onExportQrRequested: () {},
        onRemoveRequested: () {},
      ),
      WalletActivityScreen(
        entries: [],
        network: 'Sepolia',
        addressExplorer: explorer,
      ),
      WalletAutoDebitScreen(account: account, autoDebits: autoDebits),
      WalletContactsScreen(contacts: contacts),
      WalletFinanceScreen(account: account, balance: BigInt.zero, goals: goals),
      WalletHome(preferences: preferences, savePreferences: preferences.save),
      WalletSettingsScreen(
        preferences: preferences,
        save: preferences.save,
        walletName: account.name,
        canSign: false,
        canManageWallets: true,
      ),
      WalletStatementScreen(
        account: account,
        network: Network.sepolia,
        statement: statement,
        contacts: contacts,
        addressExplorer: explorer,
      ),
      const WalletImportPage(),
      WelcomeOnboardingScreen(account: account),
    ];
    const layouts = [
      (size: Size(320, 568), scale: 1.6, platform: TargetPlatform.android),
      (size: Size(844, 390), scale: 1.2, platform: TargetPlatform.iOS),
      (size: Size(768, 1024), scale: 1.0, platform: TargetPlatform.iOS),
      (size: Size(1920, 1080), scale: 1.0, platform: TargetPlatform.windows),
    ];
    tester.view.devicePixelRatio = 1;
    final layoutErrors = <String>[];
    await http.runWithClient(() async {
      for (final route in routes) {
        if (route is WalletHome) {
          FlutterSecureStorage.setMockInitialValues({
            'private_wallet.accounts.v1': jsonEncode([account]),
          });
        }
        for (final layout in layouts) {
          tester.view.physicalSize = layout.size;
          tester.view.padding = layout.size.width < 400
              ? const FakeViewPadding(top: 24, bottom: 20)
              : layout.size.height < 500
              ? const FakeViewPadding(left: 32, right: 32, bottom: 16)
              : const FakeViewPadding();
          await tester.pumpWidget(
            MaterialApp(
              theme: walletTheme(Brightness.light)
                  .copyWith(platform: layout.platform),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
              home: route,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          if (tester.takeException() case final error?) {
            layoutErrors.add('${route.runtimeType} at ${layout.size}: $error');
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }, () => MockClient((_) async => http.Response('{}', 503)));
    expect(layoutErrors, isEmpty);
  });
}
