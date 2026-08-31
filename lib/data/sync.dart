import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../supabase.dart';
import 'local_db.dart';

// The one bucket that actually exists on the live project (verified via
// list_tables/pg_policies, not assumed) — public, with no path-based
// ownership scoping on its RLS policies (bucket_id match only). Fine for
// now on a small in-house team; tighten before this app has real reach.
// See supabase/migrations/0002_storage_scoping.sql for the drafted fix.
const _bucket = 'checklist-media';

/// Pure, unit-tested (test/outbox_test.dart) — a string-matched terminal-vs-
/// retryable classification is exactly the kind of thing that silently
/// rots if the RPC's error wording ever changes.
bool isExpiredError(String message) => message.contains('ASSIGNMENT_EXPIRED');

/// Pure, unit-tested — 0002_storage_scoping.sql's RLS policy structurally
/// depends on this exact shape (`photos/{id}/...`, `signatures/{id}-...`);
/// a mismatch here silently locks every upload out.
String buildStoragePath(String key, String extension, {int? timestamp}) =>
    '$key-${timestamp ?? DateTime.now().microsecondsSinceEpoch}.$extension';

/// Drains the outbox FIFO, per assignment (§3, §7C): photos and the
/// signature must land before submit_assignment fires, or the RPC's own
/// completeness check rejects a submission whose evidence hasn't arrived.
/// Ordering by `created_at` and processing sequentially is what guarantees
/// that without any extra bookkeeping.
class SyncService {
  SyncService(this._db);
  final LocalDb _db;

  Future<void> start() async {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) drain();
    });
  }

  Future<void> drain() async {
    for (final op in await _db.outboxOps()) {
      final id = op['id'] as String;
      final assignmentId = op['assignment_id'] as String;
      final payload = op['payload'] as Map<String, dynamic>;
      try {
        await _replay(op['op'] as String, assignmentId, payload);
        await _db.dequeue(id);
      } on PostgrestExpiredException {
        // Terminal — see §2/§11. Retrying a permanent rejection is how an
        // outbox turns into an infinite battery drain; surface it instead.
        await _db.dequeue(id);
        // TODO(phase-4): surface "expired, ask your supervisor to extend"
        // via a local notification/banner keyed on assignmentId.
      } catch (_) {
        await _db.bumpAttempts(id);
        return; // stop at the first real failure — keep FIFO order intact
      }
    }
  }

  Future<void> _replay(
    String op,
    String assignmentId,
    Map<String, dynamic> payload,
  ) async {
    switch (op) {
      case 'mark_item_done':
        await supabase.rpc(
          'mark_item_done',
          params: {
            'p_item_id': payload['p_item_id'],
            'p_note': payload['p_note'],
          },
        );
        break;
      case 'attach_item_photo':
        final storagePath = await _uploadLocal(
          localPath: payload['local_file_path'] as String,
          key: 'photos/$assignmentId/${payload['p_item_id']}',
          extension: 'jpg',
        );
        await supabase.rpc(
          'attach_item_photo',
          params: {
            'p_item_id': payload['p_item_id'],
            'p_storage_path': storagePath,
          },
        );
        break;
      case 'submit_assignment':
        final signaturePath = await _uploadLocal(
          localPath: payload['local_signature_path'] as String,
          key: 'signatures/$assignmentId',
          extension: 'png',
        );
        try {
          await supabase.rpc(
            'submit_assignment',
            params: {
              'p_assignment_id': assignmentId,
              'p_signature_path': signaturePath,
              'p_completed_at': payload['completed_at'],
            },
          );
        } on PostgrestException catch (e) {
          if (isExpiredError(e.message)) throw PostgrestExpiredException();
          rethrow;
        }
        break;
      default:
        throw StateError('Unknown outbox op: $op');
    }
  }

  Future<String> _uploadLocal({
    required String localPath,
    required String key,
    required String extension,
  }) async {
    final path = buildStoragePath(key, extension);
    await supabase.storage
        .from(_bucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(upsert: true), // idempotent on replay
        );
    return path;
  }
}

class PostgrestExpiredException implements Exception {}
