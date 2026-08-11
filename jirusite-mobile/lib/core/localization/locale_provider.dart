import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('am')) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _key = 'preferred_locale';

  // Locales that Flutter's GlobalMaterialLocalizations supports.
  // om/ti use our ARB strings but fall back to 'am' for system widgets.
  static const _materialSupported = {'en', 'am'};
  static const _appSupported = {'en', 'am', 'om', 'ti'};

  Future<void> _load() async {
    final code = await _storage.read(key: _key);
    if (code != null && _appSupported.contains(code)) {
      state = Locale(code);
    } else {
      // Clear any invalid/unsupported stored locale
      await _storage.delete(key: _key);
      state = const Locale('am');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_appSupported.contains(locale.languageCode)) return;
    await _storage.write(key: _key, value: locale.languageCode);
    state = locale;
  }

  /// Returns the locale to use for Flutter's Material widgets.
  /// Falls back to 'am' for locales not in GlobalMaterialLocalizations.
  Locale get materialLocale => _materialSupported.contains(state.languageCode)
      ? state
      : const Locale('am');
}

/// Supported locales
const kSupportedLocales = [
  Locale('en'),
  Locale('am'),
  Locale('om'),
  Locale('ti'),
];

const kLocaleNames = {
  'en': 'English',
  'am': 'አማርኛ (Amharic)',
  'om': 'Afaan Oromo',
  'ti': 'ትግርኛ (Tigrinya)',
};
