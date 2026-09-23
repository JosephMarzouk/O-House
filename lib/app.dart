import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'features/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'tenant.dart';
import 'theme.dart';

class OHouseApp extends ConsumerWidget {
  const OHouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    // Keeps the outbox and its triggers (resume, reconnect, backoff) alive at
    // app level, whatever screen is showing (SY-2). listen, not watch: a new
    // service on sign-in must not rebuild the whole app.
    ref.listen(syncServiceProvider, (_, _) {});
    return MaterialApp.router(
      title: tenant.appNameEn,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
