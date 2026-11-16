import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
export 'app.dart' show PrivateWalletApp;
export 'screens/wallet_home_screen.dart' show WalletHome;

/// Inicializa o Flutter e executa o aplicativo de carteira com suporte nativo edge-to-edge.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0F1117),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 44),
              const SizedBox(height: 14),
              const Text(
                'Falha temporária ao renderizar componente',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const PrivateWalletApp());
}
