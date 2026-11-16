import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as image;
import 'package:zxing2/qrcode.dart';

import '../models/wallet_account.dart';

const syncPrefix = 'privatewallet:sync:v1:';
const maxSyncQrLength = 2048;
const importRequestPrefix = 'privatewallet:import-request:v1:';

class ImportRequestData {
  /// Inicializa [ImportRequestData] com os dados recebidos.
  const ImportRequestData({
    required this.deviceName,
    required this.platform,
    this.model,
    required this.timestamp,
    this.mode = 'import',
  });

  final String deviceName;
  final String platform;
  final String? model;
  final int timestamp;
  final String mode; // 'import' ou 'mirror'

  /// Indica se o pacote deve criar carteiras de observação.
  bool get isMirror => mode == 'mirror';

  /// Codifica a solicitação de importação para exibição em QR.
  String toQrString() {
    final payload = jsonEncode({
      'device': deviceName,
      'platform': platform,
      if (model != null && model!.isNotEmpty) 'model': model,
      'time': timestamp,
      'mode': mode,
    });
    return '$importRequestPrefix${base64UrlEncode(utf8.encode(payload))}';
  }

  /// Tenta interpretar os dados e retorna nulo quando o formato é inválido.
  static ImportRequestData? tryParse(String qr) {
    try {
      if (!qr.startsWith(importRequestPrefix)) return null;
      final raw = qr.substring(importRequestPrefix.length);
      final bytes = base64Url.decode(raw);
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return ImportRequestData(
        deviceName: map['device'] as String? ?? 'Dispositivo desconhecido',
        platform: map['platform'] as String? ?? 'Desconhecido',
        model: map['model'] as String?,
        timestamp: map['time'] as int? ?? 0,
        mode: map['mode'] as String? ?? 'import',
      );
    } catch (_) {
      return null;
    }
  }
}

class SyncPackageResult {
  /// Inicializa [SyncPackageResult] com os dados recebidos.
  const SyncPackageResult({required this.accounts, required this.isMirror});

  final List<WalletAccount> accounts;
  final bool isMirror;

  /// Retorna `singleAccount` para consulta em transferência por QR.
  WalletAccount get singleAccount => accounts.first;
}

final _cipher = AesGcm.with256bits();
final _context = utf8.encode(syncPrefix);

/// Empacota as carteiras e cifra os dados para transferência por QR.
Future<({String qr, String code})> exportWallets({
  required List<WalletAccount> accounts,
  required bool isMirror,
  DateTime? now,
}) async {
  if (accounts.isEmpty) {
    throw const FormatException(
      'Nenhuma conta disponível para exportar ou espelhar.',
    );
  }

  final key = await _cipher.newSecretKey();
  final expires = (now ?? DateTime.now()).add(const Duration(minutes: 10));

  final preparedAccounts = isMirror
      ? accounts.map((a) => a.toMirror()).toList()
      : accounts;

  final box = await _cipher.encrypt(
    utf8.encode(
      jsonEncode({
        'wallets': preparedAccounts.map((a) => a.toJson()).toList(),
        'isMirror': isMirror,
        'expires': expires.millisecondsSinceEpoch,
      }),
    ),
    secretKey: key,
    aad: _context,
  );
  final rawCode = base64UrlEncode(await key.extractBytes()).replaceAll('=', '');
  final code = RegExp('.{1,8}')
      .allMatches(rawCode)
      .map((match) => match[0])
      .join(' ');
  final qr = '$syncPrefix${base64UrlEncode(box.concatenation())}';
  if (qr.length > maxSyncQrLength) {
    throw const FormatException(
      'O pacote é grande demais para um QR. Compartilhe uma conta por vez.',
    );
  }
  return (qr: qr, code: code);
}

/// Exporta a carteira.
Future<({String qr, String code})> exportWallet(
  WalletAccount account, {
  DateTime? now,
  bool isMirror = false,
}) => exportWallets(accounts: [account], isMirror: isMirror, now: now);

/// Decifra e valida o pacote antes de reconstruir as carteiras.
Future<SyncPackageResult> importWalletsSync(
  String qr,
  String code, {
  DateTime? now,
  bool? expectedMirror,
}) async {
  if (!qr.startsWith(syncPrefix) || qr.length > maxSyncQrLength) {
    throw const FormatException(
      'Este QR code não é uma transferência do Private Wallet.',
    );
  }
  final keyText = code.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(keyText)) {
    throw const FormatException(
      'Informe o código completo exibido no outro dispositivo.',
    );
  }

  final Map<String, dynamic> data;
  try {
    final bytes = base64Url.decode(qr.substring(syncPrefix.length));
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: SecretKey(base64Url.decode('$keyText=')),
      aad: _context,
    );
    data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  } on SecretBoxAuthenticationError {
    throw const FormatException('Código incorreto ou QR code alterado.');
  } on FormatException {
    throw const FormatException('QR code inválido.');
  } on ArgumentError {
    throw const FormatException('QR code inválido.');
  }

  final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
  if (data['expires'] is! int || current >= (data['expires'] as int)) {
    throw const FormatException('Transferência expirada. Gere outro QR code.');
  }

  final isMirror = data['isMirror'] == true;
  if (expectedMirror != null && isMirror != expectedMirror) {
    throw FormatException(
      expectedMirror
          ? 'Use o QR de observação gerado no dispositivo cold.'
          : 'Selecione Cold (observação) para adicionar este QR.',
    );
  }
  final List<WalletAccount> accounts = [];

  if (data['wallets'] is List) {
    for (final item in data['wallets'] as List) {
      if (item is Map<String, dynamic>) {
        accounts.add(WalletAccount.fromJson(item));
      }
    }
  } else if (data['wallet'] is Map<String, dynamic>) {
    accounts.add(
      WalletAccount.fromJson(data['wallet'] as Map<String, dynamic>),
    );
  }

  if (accounts.isEmpty) {
    throw const FormatException(
      'Nenhuma carteira encontrada no pacote de sincronização.',
    );
  }

  return SyncPackageResult(
    accounts: isMirror
        ? accounts.map((account) => account.toMirror()).toList()
        : accounts,
    isMirror: isMirror,
  );
}

/// Importa a carteira.
Future<WalletAccount> importWallet(
  String qr,
  String code, {
  DateTime? now,
}) async {
  final result = await importWalletsSync(qr, code, now: now);
  return result.singleAccount;
}

/// Decodifica a imagem do código QR.
String decodeQrImage(Uint8List bytes) {
  try {
    final decoder = image.findDecoderForData(bytes);
    if (decoder is! image.PngDecoder && decoder is! image.JpegDecoder) {
      throw const FormatException('Escolha uma imagem PNG ou JPEG.');
    }
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width * info.height > 25000000) {
      throw const FormatException(
        'Use uma imagem PNG ou JPEG de até 25 megapixels.',
      );
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const FormatException('Imagem inválida.');
    final pixels = Int32List(decoded.width * decoded.height);
    for (final pixel in decoded) {
      pixels[pixel.y * decoded.width + pixel.x] =
          (pixel.rNormalized * 255).round() << 16 |
          (pixel.gNormalized * 255).round() << 8 |
          (pixel.bNormalized * 255).round();
    }
    final source = RGBLuminanceSource(decoded.width, decoded.height, pixels);
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
  } on FormatException {
    rethrow;
  } on Exception {
    throw const FormatException(
      'Não foi possível ler o QR code. Use uma imagem nítida.',
    );
  }
}
