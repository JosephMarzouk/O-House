import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/features/auth/login_screen.dart';
import 'package:o_house/features/splash_handoff.dart';
import 'package:o_house/l10n/app_localizations.dart';

/// The things on this screen that break silently: the empty-field guard
/// (its whole job is to not reach the network), the password reveal, the
/// phone row's direction under Arabic, and the switch to an email sign-in.
/// A real sign-in needs the API, so it stays a manual check.
///
/// Pumped at the design's 410x864 phone size — the default 800x600 test
/// surface is shorter than the form, so controls fall outside the scroll
/// viewport's clip and taps silently miss.
Future<void> _pumpLogin(WidgetTester tester, Locale locale) async {
  // splashHandoffPlayed is a one-shot flag for the whole app process — reset
  // it per test so every test sees the screen the same way a fresh app
  // launch would (expanded, animating), not whatever the previous test in
  // this file left behind.
  splashHandoffPlayed = false;

  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle(); // past the header drag-up
}

void main() {
  testWidgets('empty fields are refused before any sign-in attempt', (
    tester,
  ) async {
    await _pumpLogin(tester, const Locale('en'));

    // The guard answers before any request: the message is its own, not the
    // connection error a request in a test would end in.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your phone number and password.'), findsOneWidget);
  });

  testWidgets('password starts obscured and the eye toggle reveals it', (
    tester,
  ) async {
    await _pumpLogin(tester, const Locale('en'));

    // 0 is the phone field, 1 the password field.
    EditableText password() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(password().obscureText, isTrue);

    // While obscured the button shows the slashed eye — tapping it reveals.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(password().obscureText, isFalse);
  });

  testWidgets('the phone row stays LTR while the page mirrors to RTL', (
    tester,
  ) async {
    await _pumpLogin(tester, const Locale('ar'));

    // Page is Arabic and mirrored...
    expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(FilledButton))),
      TextDirection.rtl,
    );

    // ...but +20 and the digits after it must not be.
    expect(
      Directionality.of(tester.element(find.text('+20'))),
      TextDirection.ltr,
    );
  });

  testWidgets('an email sign-in drops the +20 row and the 10-digit cap', (
    tester,
  ) async {
    await _pumpLogin(tester, const Locale('en'));
    expect(find.text('+20'), findsOneWidget);

    await tester.tap(find.text('Sign in with email instead'));
    await tester.pumpAndSettle();

    expect(find.text('+20'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.maxLength, isNull);
    expect(field.keyboardType, TextInputType.emailAddress);
    expect(find.text('Sign in with phone number instead'), findsOneWidget);
  });

  testWidgets(
    'the Sign in button survives a keyboard tall enough to crush the old layout',
    (tester) async {
      await _pumpLogin(tester, const Locale('en'));

      // A keyboard covering ~40% of an 864-tall view — the old fixed-button
      // Column, with the header pinned above it, had nowhere left to put the
      // button and either overflowed or rendered it under the keyboard.
      tester.view.viewInsets = FakeViewPadding(
        bottom: 340 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // It's part of the scrollable form now, so it's reachable even if it
      // isn't already on screen.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    },
  );

  testWidgets(
    'a dropped connection does not redden the fields — only a rejected '
    'password does',
    (tester) async {
      await _pumpLogin(tester, const Locale('en'));

      // Past the empty-field guard, so this reaches the sign-in call — and a
      // test has no API, so it ends as no answer at all. That's exactly the
      // "no signal" case the red border must NOT fire for; only the API
      // rejecting the password (401) does.
      await tester.enterText(find.byType(TextField).first, '1004427318');
      await tester.enterText(find.byType(TextField).at(1), 'whatever12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      final phoneField = tester.widget<TextField>(find.byType(TextField).first);
      expect(phoneField.decoration?.enabledBorder, isNull);
    },
  );
}
