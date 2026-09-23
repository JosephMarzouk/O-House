import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_db.dart';

/// null = follow system locale. Set from the login screen's language toggle
/// (staff pick their language *before* signing in) or from Profile settings.
///
/// The choice is persisted to local_db's `settings` table so an Arabic-first
/// cleaner never sees an English login screen again after the first launch;
/// `profiles.locale` is the server-side mirror, applied by the splash once a
/// session exists (see profile_screen.dart and splash_screen.dart).
final localeProvider = StateNotifierProvider<LocaleController, Locale?>(
  // The shared file, not a club's: the language is chosen before any club.
  (ref) => LocaleController(LocalDb.shared),
);

class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._db) : super(null) {
    _restore();
  }

  final LocalDb _db;
  static const _key = 'locale';

  Future<void> _restore() async {
    try {
      final code = await _db.getSetting(_key);
      if (code != null) state = Locale(code);
    } catch (_) {
      // No sqflite platform (headless tests) or an unreadable db — the system
      // locale is a fine fallback, and a failed read must never block startup.
    }
  }

  Future<void> set(String code) async {
    state = Locale(code);
    try {
      await _db.setSetting(_key, code);
    } catch (_) {
      // Same as above: the toggle still works for this session.
    }
  }
}
