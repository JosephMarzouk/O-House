import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/profile/profile_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/theme.dart';

/// Profile's About and Policies show what the admin wrote in the portal
/// (club_pages), in the reader's language, and the built-in line until then.
Future<void> _pump(
  WidgetTester tester,
  Map<String, Map<String, dynamic>> pages, {
  String locale = 'en',
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userIdProvider.overrideWithValue(null), // no Supabase in tests
        currentProfileProvider.overrideWith((ref) => null),
        outboxCountProvider.overrideWith((ref) => 0),
        clubPagesProvider.overrideWith((ref) => pages),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

void main() {
  const pages = {
    'about': {
      'key': 'about',
      'body_en': 'Written by the admin',
      'body_ar': 'كتبه المدير',
    },
    'policies': {
      'key': 'policies',
      'body_en': 'No phones on the court',
      'body_ar': '',
    },
  };

  testWidgets("the admin's text, in the reader's language", (tester) async {
    await _pump(tester, pages, locale: 'ar');
    await _open(tester, Icons.info_outline);
    expect(find.text('كتبه المدير'), findsOneWidget);
  });

  testWidgets('a page with no Arabic falls back to its English', (
    tester,
  ) async {
    await _pump(tester, pages, locale: 'ar');
    await _open(tester, Icons.description_outlined);
    expect(find.text('No phones on the court'), findsOneWidget);
  });

  testWidgets('nothing written yet shows the built-in line', (tester) async {
    await _pump(tester, const {});
    await _open(tester, Icons.description_outlined);
    expect(find.textContaining('Ask your supervisor'), findsOneWidget);
  });
}
