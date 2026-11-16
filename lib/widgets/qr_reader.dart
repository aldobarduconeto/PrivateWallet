import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/wallet_sync_service.dart';

/// Indica a condição `hasMobileScanner` usada em qr reader.
bool get hasMobileScanner =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Lê a imagem do código QR.
Future<String?> readQrImage() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Imagens QR',
        extensions: ['png', 'jpg', 'jpeg'],
        uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
        mimeTypes: ['image/png', 'image/jpeg'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 12 * 1024 * 1024) {
    throw const FormatException('Escolha uma imagem de até 12 MB.');
  }
  return compute(decodeQrImage, await file.readAsBytes());
}

/// Escaneia o código QR.
Future<String?> scanQr(
  BuildContext context, {
  required String title,
  required bool Function(String) accepts,
}) => Navigator.push<String>(
  context,
  MaterialPageRoute(
    builder: (_) => _WalletScanner(title: title, accepts: accepts),
  ),
);

class _WalletScanner extends StatefulWidget {
  /// Inicializa [_WalletScanner] com os dados recebidos.
  const _WalletScanner({required this.title, required this.accepts});

  final String title;
  final bool Function(String) accepts;

  /// Cria o estado local associado ao widget.
  @override
  State<_WalletScanner> createState() => _WalletScannerState();
}

class _WalletScannerState extends State<_WalletScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _read = false;

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: MobileScanner(
      controller: _controller,
      errorBuilder: (context, error) => const Center(
        child: Text('Câmera indisponível. Volte e importe a imagem do QR.'),
      ),
      onDetect: (capture) {
        if (_read) return;
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && widget.accepts(value) && value.length <= 1024) {
            _read = true;
            Navigator.pop(context, value);
            return;
          }
        }
      },
    ),
  );
}
