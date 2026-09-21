// THROWAWAY — visual verification only, not part of the app. Mounts a chosen
// screen directly with fake data so it can be screenshotted without a real
// Supabase session. ?screen=home|tasks|profile (default profile), ?lang=ar
// for the RTL mirror. Delete after use.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/fixtures.dart';
import 'data/providers.dart';
import 'features/assignments/list_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'l10n/app_localizations.dart';
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
  final screen = Uri.base.queryParameters['screen'] ?? 'profile';
  runApp(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => _fakeProfile),
        myAssignmentsProvider.overrideWith((ref) async => demoAssignments()),
        outboxCountProvider.overrideWith((ref) async => 2),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Uri.base.queryParameters['lang'] == 'ar'
            ? const Locale('ar')
            : null,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: buildTheme(),
          child: switch (screen) {
            'home' => const HomeScreen(),
            'tasks' => const TasksListScreen(),
            _ => const ProfileScreen(),
          },
        ),
      ),
    ),
  );
}
