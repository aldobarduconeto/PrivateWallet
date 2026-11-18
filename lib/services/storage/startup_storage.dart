import 'package:flutter_secure_storage/flutter_secure_storage.dart';

extension StartupStorage on FlutterSecureStorage {
  Future<String?> readForStartup(String key) =>
      read(key: key).timeout(const Duration(seconds: 10));
}
