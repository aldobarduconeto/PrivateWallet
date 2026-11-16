import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';

/// Sistema centralizado de internacionalização (i18n) do Private Wallet.
/// O catálogo de textos próprios tem entradas em português, inglês, espanhol e alemão.
class AppLocalizations {
  /// Inicializa [AppLocalizations] com os dados recebidos.
  AppLocalizations(this.locale);

  final Locale locale;

  static final supportedLocales = AppLanguage.supportedLocales;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Obtém as traduções associadas ao contexto atual.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('pt'));
  }

  /// Retorna a tradução de `language code` no idioma atual.
  String get languageCode => locale.languageCode;

  // ==========================================================
  // TEXTOS PRINCIPAIS POR IDIOMA
  // ==========================================================

  // App & Navegação
  /// Retorna a tradução de `app title` no idioma atual.
  String get appTitle => 'Private Wallet';

  /// Retorna a tradução de `settings title` no idioma atual.
  String get settingsTitle => _t({
    'pt': 'Configurações',
    'en': 'Settings',
    'es': 'Configuración',
    'de': 'Einstellungen',
  });

  /// Retorna a tradução de `contacts title` no idioma atual.
  String get contactsTitle => _t({
    'pt': 'Contatos & Amigos',
    'en': 'Contacts & Friends',
    'es': 'Contactos & Amigos',
    'de': 'Kontakte & Freunde',
  });

  /// Retorna a tradução de `statement title` no idioma atual.
  String get statementTitle => _t({
    'pt': 'Extrato',
    'en': 'Statement',
    'es': 'Extracto',
    'de': 'Kontoauszug',
  });

  /// Retorna a tradução de `finance title` no idioma atual.
  String get financeTitle => _t({
    'pt': 'Finanças',
    'en': 'Finance',
    'es': 'Finanzas',
    'de': 'Finanzen',
  });

  /// Retorna a tradução de `auto debit title` no idioma atual.
  String get autoDebitTitle => _t({
    'pt': 'Débito Auto',
    'en': 'Auto Debit',
    'es': 'Débito Auto',
    'de': 'Lastschrift',
  });

  /// Retorna a tradução de `group purchases title` no idioma atual.
  String get groupPurchasesTitle => _t({
    'pt': 'Compras Conjuntas',
    'en': 'Group Purchases',
    'es': 'Compras Conjuntas',
    'de': 'Gemeinsame Einkäufe',
  });

  // Operações de Carteira
  /// Retorna a tradução de `create wallet` no idioma atual.
  String get createWallet => _t({
    'pt': 'Criar carteira',
    'en': 'Create wallet',
    'es': 'Crear billetera',
    'de': 'Wallet erstellen',
  });

  /// Retorna a tradução de `import private key` no idioma atual.
  String get importPrivateKey => _t({
    'pt': 'Importar chave privada',
    'en': 'Import private key',
    'es': 'Importar clave privada',
    'de': 'Privaten Schlüssel importieren',
  });

  /// Retorna a tradução de `watch address` no idioma atual.
  String get watchAddress => _t({
    'pt': 'Acompanhar endereço',
    'en': 'Watch address',
    'es': 'Observar dirección',
    'de': 'Adresse beobachten',
  });

  /// Retorna a tradução de `import qr` no idioma atual.
  String get importQr => _t({
    'pt': 'Importar por QR',
    'en': 'Import via QR',
    'es': 'Importar por QR',
    'de': 'Per QR importieren',
  });

  /// Retorna a tradução de `mirror accounts` no idioma atual.
  String get mirrorAccounts => _t({
    'pt': 'Espelhar contas',
    'en': 'Mirror accounts',
    'es': 'Reflejar cuentas',
    'de': 'Konten spiegeln',
  });

  /// Retorna a tradução de `sync qr` no idioma atual.
  String get syncQr => _t({
    'pt': 'Sincronizar por QR',
    'en': 'Sync via QR',
    'es': 'Sincronizar por QR',
    'de': 'Per QR synchronisieren',
  });

  /// Retorna a tradução de `recovery key` no idioma atual.
  String get recoveryKey => _t({
    'pt': 'Chave de recuperação',
    'en': 'Recovery key',
    'es': 'Clave de recuperación',
    'de': 'Wiederherstellungsschlüssel',
  });

  /// Retorna a tradução de `send history` no idioma atual.
  String get sendHistory => _t({
    'pt': 'Histórico de envios',
    'en': 'Send history',
    'es': 'Historial de envíos',
    'de': 'Sendeverlauf',
  });

  /// Retorna a tradução de `remove wallet` no idioma atual.
  String get removeWallet => _t({
    'pt': 'Remover carteira ativa',
    'en': 'Remove active wallet',
    'es': 'Eliminar billetera activa',
    'de': 'Aktive Wallet entfernen',
  });

  /// Retorna a tradução de `manage account` no idioma atual.
  String get manageAccount => _t({
    'pt': 'Gerenciar Carteira Ativa',
    'en': 'Manage Active Wallet',
    'es': 'Gestionar Billetera Activa',
    'de': 'Aktive Wallet verwalten',
  });

  // Ações Comuns
  /// Retorna a tradução de `send` no idioma atual.
  String get send =>
      _t({'pt': 'Enviar', 'en': 'Send', 'es': 'Enviar', 'de': 'Senden'});

  /// Retorna a tradução de `receive` no idioma atual.
  String get receive => _t({
    'pt': 'Receber',
    'en': 'Receive',
    'es': 'Recibir',
    'de': 'Empfangen',
  });

  /// Retorna a tradução de `charge` no idioma atual.
  String get charge => _t({
    'pt': 'Cobrar',
    'en': 'Request / Charge',
    'es': 'Cobrar',
    'de': 'Anfordern',
  });

  /// Retorna a tradução de `copy` no idioma atual.
  String get copy =>
      _t({'pt': 'Copiar', 'en': 'Copy', 'es': 'Copiar', 'de': 'Kopieren'});

  /// Retorna a tradução de `share` no idioma atual.
  String get share => _t({
    'pt': 'Compartilhar',
    'en': 'Share',
    'es': 'Compartir',
    'de': 'Teilen',
  });

  /// Retorna a tradução de `save` no idioma atual.
  String get save =>
      _t({'pt': 'Salvar', 'en': 'Save', 'es': 'Guardar', 'de': 'Speichern'});

  /// Retorna a tradução de `cancel` no idioma atual.
  String get cancel => _t({
    'pt': 'Cancelar',
    'en': 'Cancel',
    'es': 'Cancelar',
    'de': 'Abbrechen',
  });

  /// Retorna a tradução de `confirm` no idioma atual.
  String get confirm => _t({
    'pt': 'Confirmar',
    'en': 'Confirm',
    'es': 'Confirmar',
    'de': 'Bestätigen',
  });

  /// Retorna a tradução de `refresh` no idioma atual.
  String get refresh => _t({
    'pt': 'Atualizar saldo',
    'en': 'Refresh balance',
    'es': 'Actualizar saldo',
    'de': 'Guthaben aktualisieren',
  });

  // Tela Inicial & Boas-Vindas
  /// Retorna a tradução de `self custody badge` no idioma atual.
  String get selfCustodyBadge => _t({
    'pt': 'CARTEIRA EM AUTOCUSTÓDIA',
    'en': 'SELF-CUSTODY WALLET',
    'es': 'BILLETERA EN AUTOCUSTODIA',
    'de': 'SELF-CUSTODY WALLET',
  });

  /// Retorna a tradução de `your first wallet` no idioma atual.
  String get yourFirstWallet => _t({
    'pt': 'Sua primeira carteira',
    'en': 'Your first wallet',
    'es': 'Tu primera billetera',
    'de': 'Ihre erste Wallet',
  });

  /// Retorna a tradução de `welcome description` no idioma atual.
  String get welcomeDescription => _t({
    'pt':
        'Envie e receba Ethereum ou Bitcoin com as chaves no seu dispositivo.',
    'en': 'Send and receive Ethereum or Bitcoin with keys kept on your device.',
    'es': 'Envía y recibe Ethereum o Bitcoin con las claves en tu dispositivo.',
    'de': 'Senden und empfangen Sie Ethereum oder Bitcoin mit Schlüsseln auf Ihrem Gerät.',
  });

  /// Retorna a tradução de `add awallet` no idioma atual.
  String get addAWallet => _t({
    'pt': 'Adicionar uma carteira',
    'en': 'Add a wallet',
    'es': 'Agregar una billetera',
    'de': 'Wallet hinzufügen',
  });

  /// Retorna a tradução de `total balance` no idioma atual.
  String get totalBalance => _t({
    'pt': 'Saldo Total',
    'en': 'Total Balance',
    'es': 'Saldo Total',
    'de': 'Gesamtguthaben',
  });

  /// Retorna a tradução de `my wallets` no idioma atual.
  String get myWallets => _t({
    'pt': 'Minhas Carteiras',
    'en': 'My Wallets',
    'es': 'Mis Billeteras',
    'de': 'Meine Wallets',
  });

  // Segurança & Escudo Anti-Golpe
  /// Retorna a tradução de `security shield` no idioma atual.
  String get securityShield => _t({
    'pt': 'Escudo Anti-Golpe',
    'en': 'Anti-Scam Shield',
    'es': 'Escudo Anti-Estafa',
    'de': 'Anti-Betrugs-Schild',
  });

  /// Retorna a tradução de `visual check` no idioma atual.
  String get visualCheck => _t({
    'pt': 'Conferência Visual (4 Emojis)',
    'en': 'Visual Verification (4 Emojis)',
    'es': 'Verificación Visual (4 Emojis)',
    'de': 'Visuelle Prüfung (4 Emojis)',
  });

  /// Retorna a tradução de `sovereign id` no idioma atual.
  String get sovereignId => _t({
    'pt': 'ID Soberano',
    'en': 'Sovereign ID',
    'es': 'ID Soberano',
    'de': 'Souveräne ID',
  });

  /// Retorna a tradução de `verified contact` no idioma atual.
  String get verifiedContact => _t({
    'pt': 'Contato Verificado',
    'en': 'Verified Contact',
    'es': 'Contacto Verificado',
    'de': 'Verifizierter Kontakt',
  });

  /// Retorna a tradução de `official receipt` no idioma atual.
  String get officialReceipt => _t({
    'pt': 'Comprovante Oficial',
    'en': 'Official Receipt',
    'es': 'Comprobante Oficial',
    'de': 'Offizieller Beleg',
  });

  // Configurações e Idioma
  /// Retorna a tradução de `language section` no idioma atual.
  String get languageSection => _t({
    'pt': 'Idioma do Aplicativo',
    'en': 'App Language',
    'es': 'Idioma de la Aplicación',
    'de': 'App-Sprache',
  });

  /// Retorna a tradução de `appearance section` no idioma atual.
  String get appearanceSection => _t({
    'pt': 'Aparência & Tema',
    'en': 'Appearance & Theme',
    'es': 'Apariencia & Tema',
    'de': 'Erscheinungsbild & Design',
  });

  /// Retorna a tradução de `security section` no idioma atual.
  String get securitySection => _t({
    'pt': 'Segurança & Biometria',
    'en': 'Security & Biometrics',
    'es': 'Seguridad & Biometría',
    'de': 'Sicherheit & Biometrie',
  });

  /// Retorna a tradução de `wallets section` no idioma atual.
  String get walletsSection => _t({
    'pt': 'Carteiras & Operações',
    'en': 'Wallets & Operations',
    'es': 'Billeteras & Operaciones',
    'de': 'Wallets & Operationen',
  });

  /// Retorna a tradução de `app section` no idioma atual.
  String get appSection => _t({
    'pt': 'Aplicativo',
    'en': 'Application',
    'es': 'Aplicación',
    'de': 'Anwendung',
  });

  /// Retorna a tradução de `privacy hide balance` no idioma atual.
  String get privacyHideBalance => _t({
    'pt': 'Ocultar saldo ao iniciar',
    'en': 'Hide balance at startup',
    'es': 'Ocultar saldo al inicio',
    'de': 'Guthaben beim Start verbergen',
  });

  /// Retorna a tradução de `desktop password` no idioma atual.
  String get desktopPassword => _t({
    'pt': 'Senha do aplicativo (Desktop)',
    'en': 'App password (Desktop)',
    'es': 'Contraseña de la aplicación (Desktop)',
    'de': 'App-Passwort (Desktop)',
  });

  /// Retorna a tradução de `biometric lock` no idioma atual.
  String get biometricLock => _t({
    'pt': 'Bloqueio biométrico',
    'en': 'Biometric lock',
    'es': 'Bloqueo biométrico',
    'de': 'Biometrische Sperre',
  });

  // Contatos
  /// Retorna a tradução de `new contact` no idioma atual.
  String get newContact => _t({
    'pt': 'Novo contato',
    'en': 'New contact',
    'es': 'Nuevo contacto',
    'de': 'Neuer Kontakt',
  });

  /// Retorna a tradução de `scan qr friend` no idioma atual.
  String get scanQrFriend => _t({
    'pt': 'Escanear QR de Amigo',
    'en': 'Scan Friend QR',
    'es': 'Escanear QR de Amigo',
    'de': 'Freundes-QR scannen',
  });

  /// Retorna a tradução de `show my qr` no idioma atual.
  String get showMyQr => _t({
    'pt': 'Mostrar Meu QR Code de Amigo',
    'en': 'Show My Friend QR Code',
    'es': 'Mostrar Mi Código QR de Amigo',
    'de': 'Meinen Freundes-QR-Code anzeigen',
  });

  /// Retorna a tradução de `search contacts hint` no idioma atual.
  String get searchContactsHint => _t({
    'pt': 'Buscar por nome, @username, ID ou endereço',
    'en': 'Search by name, @username, ID or address',
    'es': 'Buscar por nombre, @username, ID o dirección',
    'de': 'Nach Name, @Benutzername, ID oder Adresse suchen',
  });

  /// Retorna a tradução de `no contacts saved` no idioma atual.
  String get noContactsSaved => _t({
    'pt': 'Nenhum contato salvo',
    'en': 'No contacts saved',
    'es': 'No hay contactos guardados',
    'de': 'Keine Kontakte gespeichert',
  });

  // Helper interno de seleção de idioma com fallback para Português
  /// Seleciona o texto correspondente ao idioma atual.
  /// Traduz “Ferramentas avançadas”.
  String get advancedTools => _t({
    'pt': 'Ferramentas avançadas',
    'en': 'Advanced tools',
    'es': 'Herramientas avanzadas',
    'de': 'Erweiterte Werkzeuge',
  });

  /// Traduz “Endereço”.
  String get address => _t({
    'pt': 'Endereço',
    'en': 'Address',
    'es': 'Dirección',
    'de': 'Adresse',
  });

  /// Traduz “Indisponível”.
  String get unavailable => _t({
    'pt': 'Indisponível',
    'en': 'Unavailable',
    'es': 'No disponible',
    'de': 'Nicht verfügbar',
  });

  /// Traduz “Consultando…”.
  String get checking => _t({
    'pt': 'Consultando…',
    'en': 'Checking…',
    'es': 'Consultando…',
    'de': 'Wird abgerufen…',
  });

  /// Traduz “Cotação de referência · somente redes principais”.
  String get referenceQuotes => _t({
    'pt': 'Cotação de referência · somente redes principais',
    'en': 'Reference prices · mainnets only',
    'es': 'Precios de referencia · solo redes principales',
    'de': 'Referenzkurse · nur Hauptnetze',
  });

  /// Traduz “Ver todos”.
  String get viewAll => _t({
    'pt': 'Ver todos',
    'en': 'View all',
    'es': 'Ver todos',
    'de': 'Alle anzeigen',
  });

  /// Traduz “Moeda de comparação”.
  String get currencyComparison => _t({
    'pt': 'Moeda de comparação',
    'en': 'Comparison currency',
    'es': 'Moneda de comparación',
    'de': 'Vergleichswährung',
  });

  /// Traduz “Idioma do aplicativo”.
  String get appLanguage => _t({
    'pt': 'Idioma do aplicativo',
    'en': 'App language',
    'es': 'Idioma de la aplicación',
    'de': 'App-Sprache',
  });

  /// Traduz “Saldo”.
  String get balanceSection =>
      _t({'pt': 'Saldo', 'en': 'Balance', 'es': 'Saldo', 'de': 'Kontostand'});

  /// Traduz “Ocultar saldo ao abrir”.
  String get hideBalanceOnOpen => _t({
    'pt': 'Ocultar saldo ao abrir',
    'en': 'Hide balance on launch',
    'es': 'Ocultar saldo al abrir',
    'de': 'Kontostand beim Start ausblenden',
  });

  /// Traduz “Ocultar saldo em segundo plano”.
  String get hideBalanceInBackground => _t({
    'pt': 'Ocultar saldo em segundo plano',
    'en': 'Hide balance in background',
    'es': 'Ocultar saldo en segundo plano',
    'de': 'Kontostand im Hintergrund ausblenden',
  });

  /// Traduz “Compras”.
  String get purchases => _t({
    'pt': 'Compras',
    'en': 'Purchases',
    'es': 'Compras',
    'de': 'Einkäufe',
  });

  /// Traduz “Envio automático habilitado.”.
  String get automaticSendingEnabled => _t({
    'pt': 'Envio automático habilitado.',
    'en': 'Automatic sending is enabled.',
    'es': 'El envío automático está activado.',
    'de': 'Automatisches Senden ist aktiviert.',
  });

  /// Traduz “Os pagamentos exigem confirmação.”.
  String get manualConfirmationRequired => _t({
    'pt': 'Os pagamentos exigem confirmação.',
    'en': 'Payments require confirmation.',
    'es': 'Los pagos requieren confirmación.',
    'de': 'Zahlungen müssen bestätigt werden.',
  });

  /// Traduz “Há um pagamento vencido.”.
  String get overduePayment => _t({
    'pt': 'Há um pagamento vencido.',
    'en': 'A payment is overdue.',
    'es': 'Hay un pago vencido.',
    'de': 'Eine Zahlung ist überfällig.',
  });

  /// Informa quando o próximo pagamento está previsto.
  String nextDebit(String date) => _t({
    'pt': 'Próximo em $date.',
    'en': 'Next due on $date.',
    'es': 'Próximo vencimiento: $date.',
    'de': 'Nächste Fälligkeit: $date.',
  });

  /// Informa quantos débitos estão ativos para a carteira.
  String activeDebits(int count) => count == 1
      ? _t({
          'pt': 'Débito ativo',
          'en': 'Active recurring payment',
          'es': 'Débito activo',
          'de': 'Aktive wiederkehrende Zahlung',
        })
      : _t({
          'pt': '$count débitos ativos',
          'en': '$count active recurring payments',
          'es': '$count débitos activos',
          'de': '$count aktive wiederkehrende Zahlungen',
        });

  /// Formata o rótulo do patrimônio consolidado com a moeda escolhida.
  String estimatedTotal(String currency, String amount) => _t({
    'pt': 'Total estimado ($currency) · $amount',
    'en': 'Estimated total ($currency) · $amount',
    'es': 'Total estimado ($currency) · $amount',
    'de': 'Geschätzte Summe ($currency) · $amount',
  });

  String _t(Map<String, String> translations) {
    return translations[locale.languageCode] ?? translations['pt'] ?? '';
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  /// Inicializa [_AppLocalizationsDelegate] com os dados recebidos.
  const _AppLocalizationsDelegate();

  /// Verifica se o locale está entre os idiomas aceitos pelo delegado.
  @override
  bool isSupported(Locale locale) =>
      AppLanguage.fromCode(locale.languageCode).locale != null;

  /// Lê os dados persistidos e prepara o estado em memória.
  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  /// Informa se as traduções precisam ser carregadas novamente.
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsExtension on BuildContext {
  /// Retorna a tradução de `l10n` no idioma atual.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
