import 'package:supabase_flutter/supabase_flutter.dart';

// Re-exported so every file that imports this wrapper also gets the
// package's types (AuthException, UserAttributes, ...) without needing its
// own direct import of supabase_flutter.
export 'package:supabase_flutter/supabase_flutter.dart';

// Initialized per club (club.dart): each club is its own Supabase project, and
// its URL and publishable key come from the API's registry when the club code
// is entered. Since Step 3 this client is for sign-in only; every read and
// write goes through the O House API (data/api_client.dart).
Future<void> initSupabase(String url, String publishableKey) =>
    Supabase.initialize(url: url, publishableKey: publishableKey);

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

/// The inverse, so Profile can show the person their own number: the API
/// never returns `phone` (it is admin-only, 0011), but it is in the sign-in
/// identity. Pure, unit-tested.
String? syntheticEmailToPhone(String? email) {
  final m = RegExp(r'^(\d+)@ohouse\.internal$').firstMatch(email ?? '');
  return m == null ? null : '+${m.group(1)}';
}
