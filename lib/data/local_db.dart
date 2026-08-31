import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Three tables, on purpose kept this small — see §8 of the plan. One
/// person's few days of work never needs a relational mirror; a JSON blob
/// cache plus a FIFO outbox is enough.
/// ponytail: JSON blob cache; normalize if cross-assignment offline queries are ever needed
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(
      join(dir.path, 'o_house.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'create table cached_assignments (id text primary key, json text not null)',
        );
        await db.execute('''
          create table outbox (
            id text primary key,
            assignment_id text not null,
            op text not null,
            payload text not null,
            attempts integer not null default 0,
            created_at text not null
          )
        ''');
        await db.execute(
          'create table settings (key text primary key, value text not null)',
        );
      },
    );
  }

  // -- cached_assignments -------------------------------------------------

  Future<void> upsertAssignment(String id, Map<String, dynamic> json) async {
    final db = await database;
    await db.insert('cached_assignments', {
      'id': id,
      'json': jsonEncode(json),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> allCachedAssignments() async {
    final db = await database;
    final rows = await db.query('cached_assignments');
    return rows
        .map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>)
        .toList();
  }

  // -- outbox ---------------------------------------------------------------
  // Each row is one RPC call: {op: 'mark_item_done', payload: {...}}, matching
  // the RPCs 1:1 (§2) — replay is "call this function with this payload,"
  // never "reconstruct a partial row update."

  Future<void> enqueue({
    required String id,
    required String assignmentId,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('outbox', {
      'id': id,
      'assignment_id': assignmentId,
      'op': op,
      'payload': jsonEncode(payload),
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// FIFO, oldest first, grouped by assignment — see sync.dart.
  Future<List<Map<String, dynamic>>> outboxOps() async {
    final db = await database;
    final rows = await db.query('outbox', orderBy: 'created_at asc');
    return rows
        .map((r) => {...r, 'payload': jsonDecode(r['payload'] as String)})
        .toList();
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
}
