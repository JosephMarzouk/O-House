// THROWAWAY — visual verification only, not part of the app. Mounts
// HomeScreen directly so its splash-hand-off animation can be screenshotted
// without a real Supabase session. Delete after use.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'models/assignment.dart';
import 'models/profile.dart';
import 'theme.dart';

const _fakeProfile = Profile(
  id: 'preview',
  name: 'Joseph Marzouk',
  phone: '+201229338195',
  role: 'cleaner',
  locale: 'en',
  active: true,
  mustChangePassword: false,
);

void main() {
  runApp(
    ProviderScope(
      // Overridden so this preview never touches Supabase (never
      // initialized here) — the whole point is to see the header without a
      // real session.
      overrides: [
        currentProfileProvider.overrideWith((ref) async => _fakeProfile),
        myAssignmentsProvider.overrideWith((ref) async => <Assignment>[]),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // ?lang=ar to preview the RTL mirror without a rebuild.
        locale: Uri.base.queryParameters['lang'] == 'ar' ? const Locale('ar') : null,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Themed(),
      ),
    ),
  );
}

class _Themed extends StatelessWidget {
  const _Themed();
  @override
  Widget build(BuildContext context) => Theme(
    data: buildTheme(),
    child: const HomeScreen(),
  );
}
