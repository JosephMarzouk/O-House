import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../tenant.dart';

/// Why a sign-in did not work, as the screen tells it.
enum SignInFailure { invalid, locked, noAccess, offline }

/// Sign-in through the O House API — the app never talks to Supabase.
///
/// The API issues two tokens: a 15-minute access token for every call, and
/// a 30-day refresh token, rotated on each use. Both live in the phone's
/// secure storage (Keystore-backed), keyed by club, so signing in survives
/// an app restart and the queue keeps its owner.
///
/// Offline is not signed out: with no network a refresh simply fails and is
/// retried later; only the API saying the refresh token is dead (401) ends
/// the session. Unsent work stays, keyed by the person (LS-5).
class AuthService extends ChangeNotifier {
  AuthService({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _http = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _http;

  String? _access;
  String? _refresh;
  String? _userId;
  String? _phone;
  Future<bool>? _refreshing;

  String get _prefix => 'auth.${tenant.clubSlug}.';

  String? get accessToken => _access;
  String? get userId => _userId;
  bool get signedIn => _userId != null && _refresh != null;

  /// The phone this person signs in with, when they sign in with one — Profile
  /// shows it. The API never returns phone numbers (admin-only).
  String? get phone => _phone;

  /// Called once at startup, before the first screen.
  Future<void> load() async {
    final all = await _storage.readAll();
    _access = all['${_prefix}access'];
    _refresh = all['${_prefix}refresh'];
    _userId = all['${_prefix}user'];
    _phone = all['${_prefix}phone'];
  }

  Future<SignInFailure?> signIn(String login, String password) async {
    final http.Response res;
    try {
      res = await _post('/auth/login', {'login': login, 'password': password});
    } catch (_) {
      return SignInFailure.offline;
    }
    switch (res.statusCode) {
      case 200:
        final phone = login.contains('@') ? null : normalizePhone(login);
        await _save(jsonDecode(res.body) as Map<String, dynamic>, phone: phone);
        return null;
      case 401:
        return SignInFailure.invalid;
      case 429:
        return SignInFailure.locked;
      case 403:
        return SignInFailure.noAccess;
      default:
        return SignInFailure.offline;
    }
  }

  /// A new token pair. True when it worked; false when the session is over
  /// (the person is signed out). Throws when there is no answer at all, so
  /// the caller retries later instead of signing anyone out for a dropped
  /// connection. Parallel callers share one refresh.
  Future<bool> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final token = _refresh;
    if (token == null) return false;
    final res = await _post('/auth/refresh', {'refreshToken': token});
    if (res.statusCode == 200) {
      await _save(jsonDecode(res.body) as Map<String, dynamic>, phone: _phone);
      return true;
    }
    if (res.statusCode == 401) {
      await _clear();
      return false;
    }
    throw http.ClientException('refresh answered ${res.statusCode}');
  }

  /// Ends the session here and, when online, at the API too.
  Future<void> signOut() async {
    final token = _refresh;
    await _clear();
    if (token != null) {
      unawaited(_post('/auth/logout', {'refreshToken': token}).then((_) {}, onError: (_) {}));
    }
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) => _http
      .post(
        Uri.parse('$apiBaseUrl$path'),
        headers: {'content-type': 'application/json', 'x-club': tenant.clubSlug},
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));

  Future<void> _save(Map<String, dynamic> t, {String? phone}) async {
    _access = t['accessToken'] as String;
    _refresh = t['refreshToken'] as String;
    _userId = t['userId'] as String;
    _phone = phone;
    await _storage.write(key: '${_prefix}access', value: _access);
    await _storage.write(key: '${_prefix}refresh', value: _refresh);
    await _storage.write(key: '${_prefix}user', value: _userId);
    if (phone != null) {
      await _storage.write(key: '${_prefix}phone', value: phone);
    } else {
      await _storage.delete(key: '${_prefix}phone');
    }
    notifyListeners();
  }

  Future<void> _clear() async {
    _access = _refresh = _userId = _phone = null;
    for (final k in ['access', 'refresh', 'user', 'phone']) {
      await _storage.delete(key: '$_prefix$k');
    }
    notifyListeners();
  }
}

/// +20 and the 10 national digits, from whatever was typed — the same rule
/// as the API's parseLogin and the portal's staff form. Pure, unit-tested.
String normalizePhone(String typed) {
  final digits = typed.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^20'), '').replaceFirst(RegExp(r'^0'), '');
  return '+20$digits';
}

/// The one instance, loaded in main() before the first screen.
final authService = AuthService();
