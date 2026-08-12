import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/generated/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import 'router.dart';
import 'theme.dart';

class JiruSiteApp extends ConsumerWidget {
  const JiruSiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'JIRUSite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: locale,
      // Only list locales that Flutter's GlobalMaterialLocalizations ships.
      // om and ti are supported by our own ARB strings but NOT by Flutter's
      // material delegates — listing them here causes "No MaterialLocalizations"
      // crashes. We handle om/ti display via our AppLocalizations delegate only.
      supportedLocales: const [
        Locale('en'),
        Locale('am'),
        Locale('om'),
      ],
      localeResolutionCallback: (requested, supported) {
        if (requested == null) return const Locale('am');
        const appLocales = ['en', 'am', 'om'];
        if (appLocales.contains(requested.languageCode)) return requested;
        return const Locale('am');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
