import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/auth_service.dart';
import 'push/push_service.dart';
import 'tenant.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every screen built so far (splash, login) is a phone-portrait design —
  // Broadsheet never drew a landscape variant, and this is a staff tool
  // carried in a pocket, not a tablet dashboard. Locking orientation avoids
  // contorting that design for a case it was never made for. No-op on
  // desktop/web.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // This build's club (its flavor). Reading `tenant` here is what fails a
  // build with a missing or wrong flavor at startup rather than somewhere
  // later — and the saved sign-in is per club, so it is read after.
  debugPrint('Club: ${tenant.clubSlug}');
  // The club's Firebase project, from its flavor's google-services.json.
  // Without one (a club with no project yet) push stays off and nothing else
  // changes. Also catches a tap that launched the app (pendingPushRoute).
  await initPush();
  await authService.load();
  runApp(const ProviderScope(child: OHouseApp()));
}
