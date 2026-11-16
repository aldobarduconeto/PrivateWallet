import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_protection_service.dart';

class PrivacyAuditScore {
  /// Inicializa [PrivacyAuditScore] com os dados recebidos.
  const PrivacyAuditScore({
    required this.score,
    required this.passedChecks,
    required this.improvementTips,
  });

  final int score;
  final List<String> passedChecks;
  final List<String> improvementTips;
}

class PrivacyStealthService {
  /// Inicializa [PrivacyStealthService] com os dados recebidos.
  const PrivacyStealthService([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _stealthModeKey = 'private_wallet.stealth_mode.v1';
  static const _decoyModeKey = 'private_wallet.decoy_mode.v1';
  static const _maskAddressesKey = 'private_wallet.mask_addresses.v1';

  /// Consulta se o modo discreto está habilitado.
  Future<bool> isStealthModeActive() async {
    final val = await _storage.read(key: _stealthModeKey);
    return val == 'true';
  }

  /// Define `stealth mode` no fluxo de privacy stealth.
  Future<void> setStealthMode(bool active) async {
    await _storage.write(key: _stealthModeKey, value: active.toString());
  }

  /// Consulta se a exibição de dados de demonstração está habilitada.
  Future<bool> isDecoyModeActive() async {
    final val = await _storage.read(key: _decoyModeKey);
    return val == 'true';
  }

  /// Define `decoy mode` no fluxo de privacy stealth.
  Future<void> setDecoyMode(bool active) async {
    await _storage.write(key: _decoyModeKey, value: active.toString());
  }

  /// Consulta se os endereços devem ser ocultados na interface.
  Future<bool> isMaskAddressesActive() async {
    final val = await _storage.read(key: _maskAddressesKey);
    return val == 'true';
  }

  /// Define `mask addresses` no fluxo de privacy stealth.
  Future<void> setMaskAddresses(bool active) async {
    await _storage.write(key: _maskAddressesKey, value: active.toString());
  }

  /// Realiza uma auditoria de privacidade e proteção da carteira
  Future<PrivacyAuditScore> runPrivacyAudit({
    required bool hasBiometrics,
    required bool isWatchOnly,
    required bool lockOnBackground,
  }) async {
    var score = 30; // Pontuação base
    final passed = <String>[];
    final tips = <String>[];

    if (hasBiometrics) {
      score += 25;
      passed.add('Bloqueio biométrico / PIN de segurança ativado.');
    } else {
      tips.add(
        'Ative a proteção biométrica ou PIN para impedir acessos físicos indesejados.',
      );
    }

    if (lockOnBackground) {
      score += 20;
      passed.add('Bloqueio automático ao minimizar em segundo plano ativado.');
    } else {
      tips.add(
        'Ative o bloqueio automático ao sair do aplicativo para evitar bisbilhoteiros.',
      );
    }

    final isStealth = await isStealthModeActive();
    if (isStealth) {
      score += 15;
      passed.add('Modo Discreto / Camuflagem ativado.');
    } else {
      tips.add(
        'Use o Modo Discreto em público para camuflar saldos e montantes na tela.',
      );
    }

    final isMasked = await isMaskAddressesActive();
    if (isMasked) {
      score += 10;
      passed.add('Ofuscação de endereços sensíveis ativada.');
    } else {
      tips.add(
        'Ative a ofuscação de endereços para não expor suas chaves públicas a terceiros.',
      );
    }

    final hasDuress = await AuthProtectionService.hasDuressPassword();
    if (hasDuress) {
      score += 10;
      passed.add('PIN de Coação (Duress PIN) configurado contra ameaças físicas.');
    } else {
      tips.add(
        'Configure um PIN de Coação para abrir a carteira isca caso seja coagido presencialmente.',
      );
    }

    return PrivacyAuditScore(
      score: score.clamp(0, 100),
      passedChecks: passed,
      improvementTips: tips,
    );
  }
}
