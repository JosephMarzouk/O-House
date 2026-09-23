import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every club has its own app — its own package name, name, icon, colours,
/// logo and Supabase project — built from this one codebase. The same tenant
/// method as the members' app: an Android flavor per club for the native
/// identity, and a [TenantConfig] entry here for everything Dart needs.
///
///     flutter run --flavor owest --dart-define=TENANT_NAME=OWEST --dart-define=ENVIRONMENT=dev
///
/// The tenant comes from the flavor itself (Flutter's [appFlavor]), so the
/// two can never disagree. TENANT_NAME is accepted for the members' app's CI
/// conventions and must match; nothing ever silently defaults to a club.
enum Tenant { owest }

/// Only public values. The Supabase secret key and the gateway key live in the
/// O House API alone (its CLUBS registry), never in an app.
class TenantConfig {
  const TenantConfig({
    required this.clubSlug,
    required this.appNameEn,
    required this.appNameAr,
    required this.clubNameEn,
    required this.clubNameAr,
    required this.supabaseUrl,
    required this.publishableKey,
    required this.ink,
    required this.accent,
    required this.accentDark,
    required this.accentTint,
    required this.logo,
  });

  /// The API registry key, sent as `X-Club` on every call.
  final String clubSlug;
  final String appNameEn;
  final String appNameAr;
  final String clubNameEn;
  final String clubNameAr;
  final String supabaseUrl;
  final String publishableKey;

  /// Brand colours: the header ink and the accent family. Magenta (alarms)
  /// and the neutrals are shared by every club (theme.dart).
  final Color ink;
  final Color accent;
  final Color accentDark;
  final Color accentTint;

  /// Under `assets/tenants/<tenant>/`.
  final String logo;

  String appName(String languageCode) => languageCode == 'ar' ? appNameAr : appNameEn;
  String clubName(String languageCode) =>
      languageCode == 'ar' ? clubNameAr : clubNameEn;
}

const tenantConfigs = {
  Tenant.owest: TenantConfig(
    clubSlug: 'ohouse',
    appNameEn: 'O House',
    appNameAr: 'او هاوس',
    clubNameEn: 'O West Sports Club',
    clubNameAr: 'نادي أو ويست الرياضي',
    supabaseUrl: 'https://ptonujazlljpkgpfrkpw.supabase.co',
    publishableKey: 'sb_publishable_E70Ct7lHtLhCUl6v4WBvpg_7MBIH66P',
    ink: Color(0xFF0E213F),
    accent: Color(0xFF0088B0),
    accentDark: Color(0xFF006786),
    accentTint: Color(0xFFE9F8FF),
    logo: 'assets/tenants/owest/logo.png',
  ),
};

/// The flavor, checked against TENANT_NAME when that is given. Throws on a
/// missing or unknown flavor, or a mismatch. Pure, unit-tested.
Tenant resolveTenant(String? flavor, String tenantName) {
  final byName = {for (final t in Tenant.values) t.name: t};
  final t = byName[flavor?.toLowerCase()];
  if (t == null) {
    throw StateError(
      'Unknown or missing flavor "$flavor". Build with --flavor '
      '${Tenant.values.map((t) => t.name).join('|')}.',
    );
  }
  if (tenantName.isNotEmpty && tenantName.toLowerCase() != t.name) {
    throw StateError('TENANT_NAME=$tenantName does not match --flavor $flavor.');
  }
  return t;
}

/// Tests have no flavor; test/flutter_test_config.dart sets this first.
@visibleForTesting
Tenant? debugTenant;

final Tenant currentTenant =
    debugTenant ??
    resolveTenant(appFlavor, const String.fromEnvironment('TENANT_NAME'));

TenantConfig get tenant => tenantConfigs[currentTenant]!;

/// ENVIRONMENT=dev → the API on this computer, reached over USB: run
/// `adb reverse tcp:4000 tcp:4000` once per connection (a phone or the
/// emulator alike). prod → the deployed API. API_URL overrides either.
String get apiBaseUrl {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) return override;
  const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
  return switch (env) {
    'dev' => 'http://127.0.0.1:4000',
    // TODO(deploy): the Railway API's URL once Step 1 is deployed.
    'prod' => throw StateError('No prod API URL yet: pass --dart-define=API_URL=...'),
    _ => throw StateError('ENVIRONMENT must be dev or prod, not "$env".'),
  };
}
