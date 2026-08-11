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

  Future<void> _load() async {
    final code = await _storage.read(key: _key);
    if (code != null) state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    await _storage.write(key: _key, value: locale.languageCode);
    state = locale;
  }
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
