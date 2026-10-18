import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every club has its own app — its own package name, name, icon, colours
/// and logo, backed by its own Supabase project behind the API — built from
/// this one codebase. The same tenant
/// method as the members' app: an Android flavor per club for the native
/// identity, and a [TenantConfig] entry here for everything Dart needs.
///
///     flutter run --flavor owest --dart-define=TENANT_NAME=OWEST --dart-define=ENVIRONMENT=dev
///
/// The tenant comes from the flavor itself (Flutter's [appFlavor]), so the
/// two can never disagree. TENANT_NAME is accepted for the members' app's CI
/// conventions and must match; nothing ever silently defaults to a club.
enum Tenant { owest, ryze, kode }

/// Only public values. The app never talks to Supabase: sign-in and every
/// read and write go through the O House API, which holds each club's
/// Supabase URL and keys (its CLUBS registry). Nothing of Supabase ships here.
class TenantConfig {
  const TenantConfig({
    required this.clubSlug,
    required this.appNameEn,
    required this.appNameAr,
    required this.clubNameEn,
    required this.clubNameAr,
    required this.ink,
    required this.accent,
    required this.accentDark,
    required this.accentTint,
    required this.onAccent,
    required this.logo,
  });

  /// The API registry key, sent as `X-Club` on every call.
  final String clubSlug;
  final String appNameEn;
  final String appNameAr;
  final String clubNameEn;
  final String clubNameAr;

  /// Brand colours: the header ink and the accent family. Magenta (alarms)
  /// and the neutrals are shared by every club (theme.dart).
  ///
  /// Taken from the members' app palettes (br-clubs-mobile-app colors.dart)
  /// by one rule, so a new club is a lookup, not a design job:
  ///   ink        = primary 500
  ///   accent     = secondary 500
  ///   accentDark = the lightest secondary shade from 600 that reaches 4.5:1
  ///                on paper (it carries text)
  ///   accentTint = secondary 50
  ///   onAccent   = text on an accent fill: white unless that is under 3:1
  ///                (RYZE's orange is 2.1:1 with white), then ink.
  /// tenant_test.dart checks the contrasts for every club.
  final Color ink;
  final Color accent;
  final Color accentDark;
  final Color accentTint;
  final Color onAccent;

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
    ink: Color(0xFF1D2749),
    accent: Color(0xFF229BA8),
    accentDark: Color(0xFF17717E),
    accentTint: Color(0xFFE5F4F5),
    onAccent: Color(0xFFFFFFFF),
    logo: 'assets/tenants/owest/owest.png',
  ),
  // TODO(club names): the clubs' official EN/AR names are still to confirm.
  Tenant.ryze: TenantConfig(
    clubSlug: 'ryze',
    appNameEn: 'RYZE House',
    appNameAr: 'رايز هاوس',
    clubNameEn: 'RYZE',
    clubNameAr: 'رايز',
    ink: Color(0xFF032F39),
    accent: Color(0xFFF69F12),
    accentDark: Color(0xFF87680A),
    accentTint: Color(0xFFF9F6ED),
    onAccent: Color(0xFF032F39),
    logo: 'assets/tenants/ryze/ryze.png',
  ),
  Tenant.kode: TenantConfig(
    clubSlug: 'kode',
    appNameEn: 'KODE House',
    appNameAr: 'كود هاوس',
    clubNameEn: 'KODE',
    clubNameAr: 'كود',
    ink: Color(0xFF234EA2),
    accent: Color(0xFFF26522),
    accentDark: Color(0xFFB34C1A),
    accentTint: Color(0xFFFDEBE1),
    onAccent: Color(0xFFFFFFFF),
    logo: 'assets/tenants/kode/kode.png',
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

/// `dev` or `prod` (the ENVIRONMENT dart-define). A release build defaults to
/// prod, so a store or pilot APK built without defines can never point at
/// this computer (F-08); debug builds still default to dev.
const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: kReleaseMode ? 'prod' : 'dev');

/// The deployed API. One API serves every club (X-Club picks the club;
/// PLAN.md "Multi-club"), so this is one URL, not one per tenant.
/// ponytail: the Railway test project's address, used for the 2-week pilot
/// (from 20 Oct 2026); change it here when production gets its own domain.
const prodApiUrl = 'https://o-house-api-production.up.railway.app';

/// ENVIRONMENT=dev → the API on this computer, reached over USB: run
/// `adb reverse tcp:4000 tcp:4000` once per connection (a phone or the
/// emulator alike; tool/run_dev.ps1 does it). prod → the deployed API.
/// API_URL overrides either.
String get apiBaseUrl => resolveApiUrl(
      environment: environment,
      override: const String.fromEnvironment('API_URL'),
      release: kReleaseMode,
    );

/// Pure, so the rules are tested without a release build. A release build
/// talks HTTPS only: staff passwords and tokens never go out in clear.
@visibleForTesting
String resolveApiUrl({required String environment, required String override, required bool release}) {
  final url = override.isNotEmpty
      ? override
      : switch (environment) {
          'dev' => 'http://127.0.0.1:4000',
          'prod' => prodApiUrl,
          _ => throw StateError('ENVIRONMENT must be dev or prod, not "$environment".'),
        };
  if (release && !url.startsWith('https://')) {
    throw StateError('A release build must use an https API, not "$url".');
  }
  return url;
}
