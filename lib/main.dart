import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
export 'app.dart' show PrivateWalletApp;
export 'screens/wallet_home_screen.dart' show WalletHome;

/// Inicializa o Flutter e executa o aplicativo de carteira com suporte nativo edge-to-edge.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const PrivateWalletApp());
}
