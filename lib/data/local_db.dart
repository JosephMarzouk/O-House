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

/// sqflite. One file: each club has its own app (tenant.dart), so its own
/// sandbox.
///
/// Every cached row and every queued op carries the user it belongs to
/// (LS-5): a shared phone never shows one person's rounds to the next, and a
/// sign-out keeps the unsent work for its owner.
///
/// Version 1 is the pre-Step-3 app's file (cached_assignments, an outbox of
/// RPC calls, settings). While the app id is unchanged the new build installs
/// OVER it, so it must be upgraded, not assumed fresh. Every later change
/// bumps [_version] with an onUpgrade step (LS-7).
class LocalDb {
  LocalDb._();
  static final instance = LocalDb._();

  static const _version = 2;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(
      join(dir.path, 'o_house.db'),
      version: _version,
      onCreate: (db, _) => _createV2(db),
      onUpgrade: (db, from, _) async {
        if (from < 2) await _fromV1(db);
      },
    );
  }

  /// The pre-Step-3 file. Its cache is only a cache: dropped, refetched. Its
  /// queue is old-format RPC calls this build cannot send (the API replaced
  /// them), but unsent work is never deleted without a person seeing it, so
  /// any rows are kept aside in `legacy_outbox` rather than dropped. The
  /// language setting carries over: `settings` has the same shape.
  static Future<void> _fromV1(Database db) async {
    await db.execute('drop table if exists cached_assignments');
    final legacy = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from outbox'),
    );
    if ((legacy ?? 0) > 0) {
      await db.execute('alter table outbox rename to legacy_outbox');
    } else {
      await db.execute('drop table if exists outbox');
    }
    await _createV2(db);
  }

  static Future<void> _createV2(Database db) async {
    await db.execute(
      'create table if not exists rounds (id text primary key, user_id text not null, json text not null)',
    );
    await db.execute(
      'create table if not exists profiles (id text primary key, json text not null)',
    );
    await db.execute('''
      create table if not exists outbox (
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
      create table if not exists drafts (
        assignment_id text not null,
        user_id text not null,
        json text not null,
        primary key (assignment_id, user_id)
      )
    ''');
    await db.execute(
      'create table if not exists settings (key text primary key, value text not null)',
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
