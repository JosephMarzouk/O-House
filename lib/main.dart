import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'supabase.dart';

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
  await initSupabase();
  runApp(const ProviderScope(child: OHouseApp()));
}
