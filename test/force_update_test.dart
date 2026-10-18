import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:o_house/app_release.dart';
import 'package:o_house/data/api_client.dart';
import 'package:o_house/data/sync.dart';
import 'package:o_house/features/update_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';

/// F-11 / MOB-01, the phone's half: the build number goes out on every call,
/// a 426 shows the Update page, and queued work waits for the new app.
void main() {
  tearDown(() {
    appBuild = const AppBuild('', 0);
    upgradeRequired.value = null;
  });

  ApiClient client(http.Client http) =>
      ApiClient(baseUrl: 'https://api', club: 'ohouse', token: () => 't', refreshSession: () async => false, client: http);

  test('every API call carries X-App-Version once the build is known', () async {
    appBuild = const AppBuild('1.0.3', 7);
    String? seen;
    await client(MockClient((r) async {
      seen = r.headers['x-app-version'];
      return http.Response('{}', 200);
    })).get('/me');
    expect(seen, '7');
  });

  test('an unknown build (tests, web) sends no version, so nothing can hold it back', () async {
    String? seen = 'unset';
    await client(MockClient((r) async {
      seen = r.headers['x-app-version'];
      return http.Response('{}', 200);
    })).get('/me');
    expect(seen, isNull);
  });

  test('a 426 records the download link and stops the drain without counting', () async {
    final api = client(MockClient((r) async => http.Response(
          '{"code":"UPGRADE_REQUIRED","updateUrl":"https://example.test/app.apk"}',
          426,
        )));
    await expectLater(api.get('/assignments'), throwsA(isA<ApiUnavailable>().having((e) => e.stopsAll, 'stopsAll', isTrue)));
    expect(upgradeRequired.value, 'https://example.test/app.apk');
    expect(parkFor(ApiUnavailable(426), maxAttempts * 2), isNull, reason: 'never parked: it waits for the update');
  });

  test('a 426 without our body still means update', () {
    noteUpgrade('<html>');
    expect(upgradeRequired.value, '');
  });

  Future<void> pumpUpdate(WidgetTester tester, Locale locale) => tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UpdateScreen(),
        ),
      );

  testWidgets('the Update page offers the download when there is a link', (tester) async {
    upgradeRequired.value = 'https://example.test/app.apk';
    await pumpUpdate(tester, const Locale('en'));
    expect(find.text('Update the app'), findsOneWidget);
    expect(find.text('Download the update'), findsOneWidget);
  });

  testWidgets('without a link it says to ask the supervisor, in Arabic too', (tester) async {
    upgradeRequired.value = '';
    await pumpUpdate(tester, const Locale('ar'));
    expect(find.text('حدّث التطبيق'), findsOneWidget);
    expect(find.text('اطلب الإصدار الجديد من مشرفك.'), findsOneWidget);
  });
}
