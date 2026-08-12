import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Fallback delegates that handle locales not supported by Flutter's built-in
/// localization delegates (GlobalMaterialLocalizations, etc.).
///
/// Flutter's built-in delegates don't support 'om' (Afaan Oromo), so we fallback
/// to 'en' for framework strings while our custom AppLocalizations handles
/// app-specific strings in Oromo.
///
/// TODO: Remove these fallbacks if a future Flutter/flutter_localizations
/// release adds native support for om.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Use 'en' fallback for om since Flutter doesn't support it
    final effectiveLocale =
        locale.languageCode == 'om' ? const Locale('en') : locale;
    return GlobalMaterialLocalizations.delegate.load(effectiveLocale);
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    // Use 'en' fallback for om since Flutter doesn't support it
    final effectiveLocale =
        locale.languageCode == 'om' ? const Locale('en') : locale;
    return GlobalCupertinoLocalizations.delegate.load(effectiveLocale);
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    // Use 'en' fallback for om since Flutter doesn't support it
    final effectiveLocale =
        locale.languageCode == 'om' ? const Locale('en') : locale;
    return GlobalWidgetsLocalizations.delegate.load(effectiveLocale);
  }

  @override
  bool shouldReload(FallbackWidgetsLocalizationsDelegate old) => false;
}