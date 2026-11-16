import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Preferência de idioma do aplicativo e catálogo de idiomas do Flutter.
class AppLanguage {
  const AppLanguage._(this.code, this.label, this.locale);

  static const system = AppLanguage._('system', 'Idioma do dispositivo', null);
  static final _languages = {
    for (final code in kMaterialSupportedLanguages)
      code: AppLanguage._(code, _nativeNames[code] ?? code, Locale(code)),
  };

  static final values = List<AppLanguage>.unmodifiable([
    system,
    ...(_languages.values.toList()..sort((a, b) => a.label.compareTo(b.label))),
  ]);

  static final supportedLocales = List<Locale>.unmodifiable([
    const Locale('pt'),
    for (final code in _languages.keys)
      if (code != 'pt') Locale(code),
  ]);

  final String code;
  final String label;
  final Locale? locale;

  /// Recupera a opção salva ou segue o idioma do dispositivo.
  static AppLanguage fromCode(String? code) =>
      _languages[code?.toLowerCase()] ?? system;

  static const _nativeNames = {
    'af': 'Afrikaans',
    'am': 'አማርኛ',
    'ar': 'العربية',
    'as': 'Assamese',
    'az': 'azərbaycan',
    'be': 'Belarusian',
    'bg': 'български',
    'bn': 'বাংলা',
    'bo': 'bo',
    'bs': 'bosanski',
    'ca': 'català',
    'cs': 'čeština',
    'cy': 'Welsh',
    'da': 'dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'es': 'español',
    'et': 'eesti',
    'eu': 'Basque',
    'fa': 'فارسی',
    'fi': 'suomi',
    'fil': 'Filipino',
    'fr': 'français',
    'ga': 'Irish',
    'gl': 'Galician',
    'gsw': 'Schwiizertüütsch',
    'gu': 'ગુજરાતી',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'hr': 'hrvatski',
    'hu': 'magyar',
    'hy': 'Armenian',
    'id': 'Indonesia',
    'is': 'Icelandic',
    'it': 'italiano',
    'ja': '日本語',
    'ka': 'Georgian',
    'kk': 'қазақ тілі',
    'km': 'Khmer',
    'kn': 'ಕನ್ನಡ',
    'ko': '한국어',
    'ky': 'Kyrgyz',
    'lo': 'Lao',
    'lt': 'lietuvių',
    'lv': 'latviešu',
    'mk': 'Macedonian',
    'ml': 'മലയാളം',
    'mn': 'Mongolian',
    'mr': 'मराठी',
    'ms': 'Melayu',
    'my': 'Burmese',
    'nb': 'norsk bokmål',
    'ne': 'Nepali',
    'nl': 'Nederlands',
    'no': 'norsk',
    'or': 'Odia',
    'pa': 'ਪੰਜਾਬੀ',
    'pl': 'polski',
    'ps': 'Pashto',
    'pt': 'português',
    'ro': 'română',
    'ru': 'русский',
    'si': 'Sinhala',
    'sk': 'slovenčina',
    'sl': 'slovenščina',
    'sq': 'Albanian',
    'sr': 'српски',
    'sv': 'svenska',
    'sw': 'Kiswahili',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'tl': 'Filipino',
    'tr': 'Türkçe',
    'ug': 'Uyghur',
    'uk': 'українська',
    'ur': 'اردو',
    'uz': 'o‘zbek',
    'vi': 'Tiếng Việt',
    'zh': '中文',
    'zu': 'Zulu',
  };
}
