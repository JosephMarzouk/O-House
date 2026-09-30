import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/features/home/home_header.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/profile.dart';

/// The header names the role from /me's `access.role` (so a custom role shows
/// its real name, in the reader's language), and falls back to the role key
/// when the API sent no names.
Profile _profile([Map<String, dynamic>? access]) => Profile.fromJson({
  'id': 'u1',
  'role': 'cleaner', // a custom role mirrors as 'cleaner'
  'access': ?access,
});

const _headOfSports = {
  'role': {'key': null, 'name_en': 'Head of Sports', 'name_ar': 'رئيس الرياضة'},
};

Future<String?> _label(WidgetTester tester, Profile? p, String locale) async {
  String? label;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          label = roleLabel(context, p);
          return const SizedBox();
        },
      ),
    ),
  );
  return label;
}

void main() {
  testWidgets("a custom role shows its own name, in the reader's language", (
    tester,
  ) async {
    expect(await _label(tester, _profile(_headOfSports), 'en'), 'Head of Sports');
    expect(await _label(tester, _profile(_headOfSports), 'ar'), 'رئيس الرياضة');
  });

  testWidgets('a missing Arabic name falls back to the English one', (
    tester,
  ) async {
    final p = _profile({
      'role': {'name_en': 'Head of Sports', 'name_ar': ''},
    });
    expect(await _label(tester, p, 'ar'), 'Head of Sports');
  });

  testWidgets('no access (an older API) keeps the title-cased key', (
    tester,
  ) async {
    expect(await _label(tester, _profile(), 'en'), 'Cleaner');
    expect(await _label(tester, _profile(), 'ar'), 'Cleaner');
  });

  testWidgets('no profile yet: no label', (tester) async {
    expect(await _label(tester, null, 'en'), isNull);
  });
}
