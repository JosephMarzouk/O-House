import 'package:supabase_flutter/supabase_flutter.dart';

// Re-exported so every file that imports this wrapper also gets the
// package's types (PostgrestException, FileOptions, UserAttributes, ...)
// without needing its own direct import of supabase_flutter.
export 'package:supabase_flutter/supabase_flutter.dart';

// Project "Check List" (ptonujazlljpkgpfrkpw). Publishable key only —
// safe to ship in the client, RLS + SECURITY DEFINER RPCs do the real
// enforcement (see supabase/migrations/0001_ohouse_app.sql).
const _supabaseUrl = 'https://ptonujazlljpkgpfrkpw.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_E70Ct7lHtLhCUl6v4WBvpg_7MBIH66P';

Future<void> initSupabase() => Supabase.initialize(
  url: _supabaseUrl,
  publishableKey: _supabasePublishableKey,
);

SupabaseClient get supabase => Supabase.instance.client;

// Fallback auth path: this project's Phone provider isn't enabled (no SMS
// provider configured — confirmed via the dashboard's "Add user" screen
// only offering Email/Password, no Phone field). Rather than block on
// that infrastructure decision, staff sign in with a phone number that
// is quietly mapped to a disguised email underneath — login_screen.dart
// never shows "email" anywhere. `.internal` is IETF-reserved for exactly
// this kind of address that must never be a real, reachable domain.
// Swap this out if/when real phone+SMS auth gets switched on later —
// only this function and its one call site change.
String phoneToSyntheticEmail(String e164Phone) =>
    '${e164Phone.replaceFirst('+', '')}@ohouse.internal';
