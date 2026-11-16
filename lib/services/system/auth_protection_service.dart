import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'privacy_stealth_service.dart';

enum AuthStatus {
  success,
  duress,
  invalid,
  rateLimited,
}

class AuthVerifyResult {
  const AuthVerifyResult({
    required this.status,
    this.remainingLockoutSeconds = 0,
    this.failedAttempts = 0,
    this.message,
  });

  final AuthStatus status;
  final int remainingLockoutSeconds;
  final int failedAttempts;
  final String? message;

  bool get isSuccess => status == AuthStatus.success;
  bool get isDuress => status == AuthStatus.duress;
  bool get isRateLimited => status == AuthStatus.rateLimited;
}

/// Serviço de proteção e autenticação soberana da carteira.
/// Opera 100% offline no dispositivo sem depender de e-mail, telefone, SMS ou servidores remotos.
class AuthProtectionService {
  static const _channel = MethodChannel('com.awesome/auth');
  static const _storage = FlutterSecureStorage();

  // Chaves do PIN/Senha Mestra
  static const _passHashKey = 'private_wallet.master_password_hash';
  static const _passSaltKey = 'private_wallet.master_password_salt';
  // Chaves para compatibilidade desktop legada
  static const _legacyDesktopHashKey = 'private_wallet.desktop_password_hash';
  static const _legacyDesktopSaltKey = 'private_wallet.desktop_password_salt';

  // Chaves do PIN de Coação (Duress PIN - Anti-Wrench Attack)
  static const _duressHashKey = 'private_wallet.duress_password_hash';
  static const _duressSaltKey = 'private_wallet.duress_password_salt';

  // Chaves de controle de força bruta (Rate Limiting)
  static const _failedAttemptsKey = 'private_wallet.auth_failed_attempts';
  static const _lockoutUntilKey = 'private_wallet.auth_lockout_until';

  /// Indica se o ambiente atual é desktop.
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Indica se o ambiente atual é móvel.
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Verifica se o dispositivo móvel suporta autenticação biométrica ou facial.
  static Future<bool> canCheckBiometrics() async {
    if (!isMobile) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'canAuthenticateBiometrics',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dispara o diálogo nativo de biometria / reconhecimento facial.
  static Future<bool> authenticateBiometrics({
    String title = 'Autenticação Private Wallet',
    String subtitle =
        'Identifique-se com sua biometria ou reconhecimento facial',
  }) async {
    if (!isMobile) return true;
    try {
      final res = await _channel.invokeMethod<bool>('authenticateBiometrics', {
        'title': title,
        'subtitle': subtitle,
      });
      return res ?? false;
    } catch (_) {
      return true;
    }
  }

  // ========================================================
  // CONTROLE DE TAXA / RATE LIMITING CONTRA FORÇA BRUTA
  // ========================================================

  /// Retorna quantos segundos restam no bloqueio temporário por tentativas falhas.
  static Future<int> getLockoutRemainingSeconds() async {
    final lockoutStr = await _storage.read(key: _lockoutUntilKey);
    if (lockoutStr == null) return 0;
    final lockoutMillis = int.tryParse(lockoutStr) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockoutMillis > now) {
      return ((lockoutMillis - now) / 1000).ceil();
    }
    return 0;
  }

  /// Registra uma tentativa falha e calcula tempo de espera exponencial se exceder o limite.
  static Future<int> _recordFailedAttempt() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final count = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: count.toString());

    var lockoutSeconds = 0;
    if (count >= 10) {
      lockoutSeconds = 300; // 5 minutos de trava
    } else if (count >= 5) {
      lockoutSeconds = 30; // 30 segundos
    } else if (count >= 3) {
      lockoutSeconds = 5; // 5 segundos
    }

    if (lockoutSeconds > 0) {
      final lockoutUntil = DateTime.now()
          .add(Duration(seconds: lockoutSeconds))
          .millisecondsSinceEpoch;
      await _storage.write(
        key: _lockoutUntilKey,
        value: lockoutUntil.toString(),
      );
    }

    return lockoutSeconds;
  }

  /// Zera o contador de tentativas incorretas após uma autenticação bem-sucedida.
  static Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  // ========================================================
  // PIN / SENHA MESTRA LOCAL (UNIVERSAL MOBILE & DESKTOP)
  // ========================================================

  /// Verifica se o usuário configurou uma senha ou PIN mestre.
  static Future<bool> hasMasterPassword() async {
    final hash = await _storage.read(key: _passHashKey) ??
        await _storage.read(key: _legacyDesktopHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Define ou altera o PIN ou senha mestra com hash SHA-256 e sal CSPRNG de 128 bits.
  static Future<void> setMasterPassword(String password) async {
    final trimmed = password.trim();
    if (trimmed.length < 4) {
      throw const FormatException('O PIN ou senha deve ter pelo menos 4 dígitos/caracteres.');
    }

    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final saltHex = saltBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final sha256Algorithm = Sha256();
    final hash = await sha256Algorithm.hash(utf8.encode('$saltHex$trimmed'));
    final hashHex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    await _storage.write(key: _passSaltKey, value: saltHex);
    await _storage.write(key: _passHashKey, value: hashHex);
    // Também sincroniza a chave legada para retrocompatibilidade
    await _storage.write(key: _legacyDesktopSaltKey, value: saltHex);
    await _storage.write(key: _legacyDesktopHashKey, value: hashHex);
  }

  /// Remove o PIN ou senha mestra.
  static Future<void> removeMasterPassword() async {
    await _storage.delete(key: _passHashKey);
    await _storage.delete(key: _passSaltKey);
    await _storage.delete(key: _legacyDesktopHashKey);
    await _storage.delete(key: _legacyDesktopSaltKey);
  }

  // ========================================================
  // PIN DE COAÇÃO (DURESS PIN - SILENT DECOY WALLET)
  // ========================================================

  /// Verifica se o usuário cadastrou um PIN de Coação.
  static Future<bool> hasDuressPassword() async {
    final hash = await _storage.read(key: _duressHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Define um PIN de Coação. Deve ser diferente da senha mestra.
  static Future<void> setDuressPassword(String duressPassword) async {
    final trimmed = duressPassword.trim();
    if (trimmed.length < 4) {
      throw const FormatException('O PIN de coação deve ter pelo menos 4 dígitos/caracteres.');
    }

    // Garante que o PIN de coação não seja idêntico à senha mestra
    if (await hasMasterPassword()) {
      final isSameAsMaster = await _verifyRaw(
        trimmed,
        hashKey: _passHashKey,
        saltKey: _passSaltKey,
      );
      if (isSameAsMaster) {
        throw const FormatException('O PIN de coação deve ser diferente do seu PIN/senha mestre.');
      }
    }

    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final saltHex = saltBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final sha256Algorithm = Sha256();
    final hash = await sha256Algorithm.hash(utf8.encode('$saltHex$trimmed'));
    final hashHex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    await _storage.write(key: _duressSaltKey, value: saltHex);
    await _storage.write(key: _duressHashKey, value: hashHex);
  }

  /// Remove o PIN de coação cadastrado.
  static Future<void> removeDuressPassword() async {
    await _storage.delete(key: _duressHashKey);
    await _storage.delete(key: _duressSaltKey);
  }

  // ========================================================
  // VERIFICAÇÃO UNIFICADA COM SUPORTE A DURESS E RATE LIMIT
  // ========================================================

  /// Valida o PIN ou senha informada.
  /// Detecta se é a senha real ou se é o PIN de Coação (que ativa a Decoy Wallet silenciosamente).
  static Future<AuthVerifyResult> verifyCredentials(String input) async {
    final trimmed = input.trim();

    // 1. Checa trava de força bruta
    final lockoutSeconds = await getLockoutRemainingSeconds();
    if (lockoutSeconds > 0) {
      return AuthVerifyResult(
        status: AuthStatus.rateLimited,
        remainingLockoutSeconds: lockoutSeconds,
        message: 'Muitas tentativas falhas. Aguarde $lockoutSeconds segundos.',
      );
    }

    // 2. Checa se corresponde ao PIN de Coação
    if (await hasDuressPassword()) {
      final isDuress = await _verifyRaw(
        trimmed,
        hashKey: _duressHashKey,
        saltKey: _duressSaltKey,
      );
      if (isDuress) {
        await _resetFailedAttempts();
        // Ativa imediatamente o Modo Isca / Decoy silenciosamente
        const stealth = PrivacyStealthService();
        await stealth.setDecoyMode(true);
        return const AuthVerifyResult(
          status: AuthStatus.duress,
          message: 'Desbloqueado em modo de segurança demonstrativo.',
        );
      }
    }

    // 3. Checa a senha mestra normal
    final isMasterValid = await _verifyRaw(
          trimmed,
          hashKey: _passHashKey,
          saltKey: _passSaltKey,
        ) ||
        await _verifyRaw(
          trimmed,
          hashKey: _legacyDesktopHashKey,
          saltKey: _legacyDesktopSaltKey,
        );

    if (isMasterValid) {
      await _resetFailedAttempts();
      return const AuthVerifyResult(status: AuthStatus.success);
    }

    // 4. Falha na autenticação
    final penalty = await _recordFailedAttempt();
    final rawAttempts = await _storage.read(key: _failedAttemptsKey);
    final attempts = int.tryParse(rawAttempts ?? '1') ?? 1;

    return AuthVerifyResult(
      status: penalty > 0 ? AuthStatus.rateLimited : AuthStatus.invalid,
      remainingLockoutSeconds: penalty,
      failedAttempts: attempts,
      message: penalty > 0
          ? 'Muitas tentativas incorretas. Carteira bloqueada temporariamente por $penalty segundos.'
          : 'PIN ou senha incorreta.',
    );
  }

  /// Executa o cálculo de hash e conferência contra o Secure Storage.
  static Future<bool> _verifyRaw(
    String password, {
    required String hashKey,
    required String saltKey,
  }) async {
    final storedHash = await _storage.read(key: hashKey);
    final storedSalt = await _storage.read(key: saltKey);
    if (storedHash == null || storedSalt == null) return false;

    final sha256Algorithm = Sha256();
    final hash = await sha256Algorithm.hash(
      utf8.encode('$storedSalt$password'),
    );
    final computedHex = hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return computedHex == storedHash;
  }

  // ========================================================
  // ALIASES DE RETROCOMPATIBILIDADE
  // ========================================================

  static Future<bool> hasDesktopPassword() => hasMasterPassword();
  static Future<void> setDesktopPassword(String password) => setMasterPassword(password);
  static Future<bool> verifyDesktopPassword(String password) async {
    final res = await verifyCredentials(password);
    return res.isSuccess || res.isDuress;
  }
  static Future<void> removeDesktopPassword() => removeMasterPassword();
}
