import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// One queued write. [id] is fixed at capture and doubles as the request's
/// Idempotency-Key, so a replay after a lost response is recognisably the
/// same op. Ops run in [seq] order (sqlite's rowid: insertion order, with no
/// clock ties).
class OutboxOp {
  OutboxOp({
    required this.seq,
    required this.id,
    required this.userId,
    required this.assignmentId,
    required this.op,
    required this.payload,
    required this.attempts,
    required this.parkedCode,
    required this.parkedMessage,
  });

  final int seq;
  final String id;
  final String userId;
  final String assignmentId;

  /// answer | photo | submit
  final String op;
  final Map<String, dynamic> payload;
  final int attempts;

  /// Set when the API refused it (SY-6): the op waits for Retry or Dismiss.
  final String? parkedCode;
  final String? parkedMessage;
  bool get parked => parkedCode != null;

  factory OutboxOp.fromRow(Map<String, Object?> r) => OutboxOp(
    seq: r['seq'] as int,
    id: r['id'] as String,
    userId: r['user_id'] as String,
    assignmentId: r['assignment_id'] as String,
    op: r['op'] as String,
    payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
    attempts: r['attempts'] as int,
    parkedCode: r['parked_code'] as String?,
    parkedMessage: r['parked_message'] as String?,
  );
}

/// sqflite, one file per club (club.dart) plus a shared one for settings.
///
/// Every cached row and every queued op carries the user it belongs to
/// (LS-5): a shared phone never shows one person's rounds to the next, and a
/// sign-out keeps the unsent work for its owner.
///
/// Fresh schema at version 1: Step 3 ships under a new app id, so there is no
/// old file to migrate. Every later change bumps [_version] with an
/// onUpgrade step (LS-7).
///
/// ponytail: every file gets every table, though the shared one only uses
/// `settings` and club files never do. Six empty tables cost nothing.
class LocalDb {
  LocalDb.named(this.fileName);

  /// The club choice and the language: things that exist before any club.
  static final shared = LocalDb.named('o_house.db');

  final String fileName;
  static const _version = 1;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(
      join(dir.path, fileName),
      version: _version,
      onCreate: (db, _) async {
        await db.execute(
          'create table rounds (id text primary key, user_id text not null, json text not null)',
        );
        await db.execute(
          'create table profiles (id text primary key, json text not null)',
        );
        await db.execute('''
          create table outbox (
            seq integer primary key autoincrement,
            id text not null unique,
            user_id text not null,
            assignment_id text not null,
            op text not null,
            payload text not null,
            attempts integer not null default 0,
            parked_code text,
            parked_message text,
            created_at text not null
          )
        ''');
        await db.execute('''
          create table drafts (
            assignment_id text not null,
            user_id text not null,
            json text not null,
            primary key (assignment_id, user_id)
          )
        ''');
        await db.execute(
          'create table settings (key text primary key, value text not null)',
        );
      },
    );
  }

  // -- rounds: the user's offline set -----------------------------------------

  /// Replaces [userId]'s cached rounds with the server's list. The list is
  /// the whole offline window (7 days back, the future, open follow-ups), so
  /// replacing is also the pruning (LS-6): a round that aged out is dropped.
  Future<void> replaceRounds(
    String userId,
    List<Map<String, dynamic>> rounds,
  ) async {
    final db = await database;
    await db.transaction((tx) async {
      await tx.delete('rounds', where: 'user_id = ?', whereArgs: [userId]);
      final batch = tx.batch();
      for (final r in rounds) {
        batch.insert('rounds', {
          'id': r['id'],
          'user_id': userId,
          'json': jsonEncode(r),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> rounds(String userId) async {
    final db = await database;
    final rows = await db.query(
      'rounds',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return [
      for (final r in rows) jsonDecode(r['json'] as String) as Map<String, dynamic>,
    ];
  }

  // -- profile ----------------------------------------------------------------

  Future<void> saveProfile(String id, Map<String, dynamic> json) async {
    final db = await database;
    await db.insert('profiles', {
      'id': id,
      'json': jsonEncode(json),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> profile(String id) async {
    final db = await database;
    final rows = await db.query('profiles', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
  }

  // -- outbox -----------------------------------------------------------------

  Future<void> enqueue({
    required String id,
    required String userId,
    required String assignmentId,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('outbox', {
      'id': id,
      'user_id': userId,
      'assignment_id': assignmentId,
      'op': op,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// [userId]'s ops, oldest first, parked ones included.
  Future<List<OutboxOp>> ops(String userId) async {
    final db = await database;
    final rows = await db.query(
      'outbox',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'seq',
    );
    return rows.map(OutboxOp.fromRow).toList();
  }

  Future<void> dequeue(String id) async {
    final db = await database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> bumpAttempts(String id) async {
    final db = await database;
    await db.rawUpdate(
      'update outbox set attempts = attempts + 1 where id = ?',
      [id],
    );
  }

  Future<void> park(String id, String code, String message) async {
    final db = await database;
    await db.update(
      'outbox',
      {'parked_code': code, 'parked_message': message},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Retry: back into the queue, same id, same evidence.
  Future<void> unpark(String id) async {
    final db = await database;
    await db.update(
      'outbox',
      {'parked_code': null, 'parked_message': null, 'attempts': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -- drafts: answers and photos staged on a round, before Submit (LS-2) -----

  Future<void> saveDraft(
    String userId,
    String assignmentId,
    Map<String, dynamic> json,
  ) async {
    final db = await database;
    await db.insert('drafts', {
      'assignment_id': assignmentId,
      'user_id': userId,
      'json': jsonEncode(json),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> draft(String userId, String assignmentId) async {
    final db = await database;
    final rows = await db.query(
      'drafts',
      where: 'user_id = ? and assignment_id = ?',
      whereArgs: [userId, assignmentId],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['json'] as String) as Map<String, dynamic>;
  }

  Future<void> deleteDraft(String userId, String assignmentId) async {
    final db = await database;
    await db.delete(
      'drafts',
      where: 'user_id = ? and assignment_id = ?',
      whereArgs: [userId, assignmentId],
    );
  }

  // -- settings ---------------------------------------------------------------

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }
}
