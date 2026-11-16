import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/wallet_contact.dart';

class ContactStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'private_wallet.contacts.v1';

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<List<WalletContact>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final contacts = <WalletContact>[];
    for (final row in jsonDecode(raw) as List<dynamic>) {
      try {
        contacts.add(WalletContact.fromJson(row as Map<String, dynamic>));
      } on Object {
        // Um contato corrompido não impede a leitura dos demais.
      }
    }
    return contacts;
  }

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> save(List<WalletContact> contacts) =>
      _storage.write(key: _key, value: jsonEncode(contacts));
}
