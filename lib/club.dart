import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'data/local_db.dart';
import 'supabase.dart';

/// The API every club shares. Release builds must pass
/// `--dart-define=API_URL=https://api.<product>.app`; debug falls back to the
/// host machine as the Android emulator sees it.
const _apiUrlDefine = String.fromEnvironment('API_URL');
String get kApiUrl {
  if (_apiUrlDefine.isNotEmpty) return _apiUrlDefine;
  if (kReleaseMode) throw StateError('Build with --dart-define=API_URL=...');
  return 'http://10.0.2.2:4000';
}

/// One club: its own Supabase project (sign-in, data, storage) and branding.
/// The public half of the API's registry entry, from `GET /clubs/:code`.
class Club {
  const Club({
    required this.slug,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.logoUrl,
    required this.supabaseUrl,
    required this.publishableKey,
  });

  final String slug;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? logoUrl;
  final String supabaseUrl;
  final String publishableKey;

  factory Club.fromJson(Map<String, dynamic> j) => Club(
    slug: j['slug'] as String,
    code: j['code'] as String,
    nameEn: (j['name'] as Map)['en'] as String? ?? '',
    nameAr: (j['name'] as Map)['ar'] as String? ?? '',
    logoUrl: j['logoUrl'] as String?,
    supabaseUrl: j['supabaseUrl'] as String,
    publishableKey: j['publishableKey'] as String,
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'code': code,
    'name': {'en': nameEn, 'ar': nameAr},
    'logoUrl': logoUrl,
    'supabaseUrl': supabaseUrl,
    'publishableKey': publishableKey,
  };
}

/// The club this phone is signed into, or null before the code is entered.
/// Process-wide on purpose: Supabase itself is a process-wide singleton, and
/// the two must never disagree.
Club? currentClub;

/// Every club's queue and cache live in their own file (plan: one local
/// database per club), so switching clubs can never mix them. The club choice
/// itself and the language live in the shared file.
LocalDb clubDb(Club club) => LocalDb.named('o_house_${club.slug}.db');

const _clubKey = 'club';

/// Boot: the saved club, if any, and Supabase initialized for it.
Future<void> restoreClub() async {
  String? saved;
  try {
    saved = await LocalDb.shared.getSetting(_clubKey);
  } catch (_) {
    // No sqflite (web preview, tests): behave as a first launch.
  }
  if (saved == null) return;
  await _activate(Club.fromJson(jsonDecode(saved) as Map<String, dynamic>));
}

/// Thrown by [lookUpClub] when the API answers but knows no such code.
class UnknownClubCode implements Exception {}

/// `GET /clubs/:code`. Anything but a 200 or a 404 is the network's fault
/// and surfaces as the http exception.
Future<Club> lookUpClub(String code, {http.Client? client}) async {
  final c = client ?? http.Client();
  final res = await c
      .get(Uri.parse('$kApiUrl/clubs/${Uri.encodeComponent(code.trim())}'))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) throw UnknownClubCode();
  if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
  return Club.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

/// Saves [club] as this phone's club and points Supabase at it. The caller
/// signs out of the previous club first (Profile → Switch club), and that
/// club's unsent work stays in its own file for when its owner returns.
Future<void> chooseClub(Club club) async {
  await LocalDb.shared.setSetting(_clubKey, jsonEncode(club.toJson()));
  await _activate(club);
}

Future<void> forgetClub() async {
  await LocalDb.shared.deleteSetting(_clubKey);
  if (currentClub != null) await Supabase.instance.dispose();
  currentClub = null;
  clubChanges.value++;
}

Future<void> _activate(Club club) async {
  if (currentClub != null) await Supabase.instance.dispose();
  await initSupabase(club.supabaseUrl, club.publishableKey);
  currentClub = club;
  clubChanges.value++;
}

/// Bumped whenever [currentClub] changes, so the router and providers re-run.
final clubChanges = ValueNotifier<int>(0);
