import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_wallet/app.dart';
import 'package:private_wallet/l10n/app_localizations.dart';
import 'package:private_wallet/screens/wallet_home_screen.dart';
import 'package:private_wallet/services/system/header_command_service.dart';
import 'package:private_wallet/widgets/desktop_title_bar.dart';

void main() {
  testWidgets('first launch shows setup options after a storage retry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const storage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    final pendingRead = Completer<String?>();
    messenger.setMockMethodCallHandler(storage, (_) => pendingRead.future);
    addTearDown(() => messenger.setMockMethodCallHandler(storage, null));

    await tester.pumpWidget(const PrivateWalletApp());
    await tester.pump(const Duration(seconds: 11));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(WalletHome), findsNothing);

    messenger.setMockMethodCallHandler(storage, (_) async => null);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    pendingRead.complete(null);

    final l10n = tester.element(find.byType(WalletHome)).l10n;
    expect(find.text(l10n.yourFirstWallet), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    for (final label in [l10n.createWallet, l10n.importPrivateKey]) {
      final action = find.text(label);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Escolher ativo e rede'), findsOneWidget);
      Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
      await tester.pumpAndSettle();
    }
    HeaderCommandService.instance.stopGasMonitoring();
  });

  testWidgets('shows the wallet after loading preferences', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'private_wallet.preferences.v1': '{"hideBalanceAtStartup":true}',
    });
    await tester.pumpWidget(const PrivateWalletApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    HeaderCommandService.instance.stopGasMonitoring();

    expect(find.byType(WalletHome), findsOneWidget);
    expect(find.byType(DesktopTitleBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(HeaderCommandService.instance.hideBalanceNotifier.value, isTrue);
  });
}
