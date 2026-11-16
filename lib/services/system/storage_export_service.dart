import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'app_permissions_service.dart';

class StorageExportService {
  /// Salva o comprovante bancário oficial como arquivo de texto no armazenamento do aparelho.
  static Future<String?> saveReceiptFile({
    required String receiptContent,
    required String defaultFileName,
  }) async {
    await AppPermissionsService.request(AppPermission.storage);

    try {
      final fileName = defaultFileName.endsWith('.txt')
          ? defaultFileName
          : '$defaultFileName.txt';

      final fileBytes = Uint8List.fromList(utf8.encode(receiptContent));

      final saveLocation = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Comprovante Bancário Cripto (*.txt)',
            extensions: ['txt'],
            mimeTypes: ['text/plain'],
          ),
        ],
      );

      if (saveLocation == null) return null;

      final file = XFile.fromData(
        fileBytes,
        name: fileName,
        mimeType: 'text/plain',
      );
      await file.saveTo(saveLocation.path);
      return saveLocation.path;
    } catch (_) {
      return null;
    }
  }

  /// Salva o extrato consolidado da carteira no armazenamento.
  static Future<String?> saveStatementFile({
    required String statementContent,
    required String walletName,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return saveReceiptFile(
      receiptContent: statementContent,
      defaultFileName:
          'extrato_${walletName.toLowerCase().replaceAll(' ', '_')}_$dateStr.txt',
    );
  }
}
