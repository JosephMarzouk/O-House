import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';

/// F-13 / FIELD-03 / FIELD-04: a refused or broken camera is never silent.
/// The camera itself is image_picker's; here a fake stands in for it.
Future<void> _tapCamera(WidgetTester tester, Future<XFile?> Function() camera, {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openCamera(context, camera),
            child: const Text('camera'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('camera'));
  await tester.pumpAndSettle();
}

void main() {
  test('F-13: the manifest declares CAMERA, so image_picker asks before opening the camera', () async {
    // Tests run from the package root.
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.CAMERA'));
  });

  testWidgets('a refused camera explains why and offers Open settings', (tester) async {
    await _tapCamera(tester, () async => throw PlatformException(code: 'camera_access_denied'));
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Camera access needed'), findsNothing);
  });

  testWidgets('the same, in Arabic', (tester) async {
    await _tapCamera(tester, () async => throw PlatformException(code: 'camera_access_denied'), locale: const Locale('ar'));
    expect(find.text('مطلوب إذن الكاميرا'), findsOneWidget);
  });

  testWidgets('any other camera error says so instead of doing nothing', (tester) async {
    await _tapCamera(tester, () async => throw PlatformException(code: 'no_available_camera'));
    expect(find.textContaining("camera couldn't open"), findsOneWidget);
  });

  test('B10: a capture lost to Android is recovered only on its own round', () {
    final json = pendingCaptureJson('round-1', 'item-7', 'mp4');
    expect(pendingCaptureFor(json, 'round-1'), (item: 'item-7', ext: 'mp4'));
    expect(pendingCaptureFor(json, 'round-2'), isNull, reason: "left for its own round");
    expect(pendingCaptureFor(null, 'round-1'), isNull);
    expect(pendingCaptureFor('junk', 'round-1'), isNull);
    expect(pendingCaptureFor(pendingCaptureJson('r', 'i', 'jpg'), 'r'), (item: 'i', ext: 'jpg'));
  });

  testWidgets('a cancelled camera is not an error', (tester) async {
    await _tapCamera(tester, () async => null);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
