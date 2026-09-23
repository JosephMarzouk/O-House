import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../supabase.dart';
import 'local_db.dart';

// The one bucket that actually exists on the live project (verified via
// list_tables/pg_policies, not assumed) — public, with no path-based
// ownership scoping on its RLS policies (bucket_id match only). Fine for
// now on a small in-house team; tighten before this app has real reach.
// See supabase/migrations/0002_storage_scoping.sql for the drafted fix.
const kMediaBucket = 'checklist-media';

/// Errors the RPC raises and will keep raising, however many times the op is
/// replayed. The client gate should have prevented every one of them, so a
/// retry is an infinite loop, not a recovery.
///
/// INCOMPLETE stays listed even though 0006_partial_submit.sql stopped
/// raising it: an app build can perfectly well run against a database that
/// has not had 0006 applied yet, and that is precisely the case where the
/// op would otherwise loop forever.
///
/// Matched against the exact strings 0001_ohouse_app.sql raises, not on a
/// loose substring like 'not found' — over-matching here silently destroys
/// work, which is the one failure mode worse than a stuck queue.
const _terminalSignals = {
  // submit_assignment
  'ASSIGNMENT_EXPIRED',
  'EMPTY_SUBMISSION',
  'MISSING_PHOTO',
  'INCOMPLETE',
  'Assignment not found',
  // mark_item_done / attach_item_photo. An op naming a row that no longer
  // exists, or a round that has closed, can never succeed however long it is
  // replayed — the assignment was deleted and recreated, or an admin approved
  // it out from under the device. These were the queue-jamming ones: the
  // classifier used to be consulted only inside the submit_assignment case,
  // so an 'Item not found' from a tick went to the retryable branch and
  // stopped the whole outbox forever.
  'Item not found',
  'Not authorized',
  'Assignment is closed',
};

/// Pure, unit-tested (test/outbox_test.dart) — a string-matched terminal-vs-
/// retryable classification is exactly the kind of thing that silently
/// rots if the RPC's error wording ever changes.
bool isTerminalError(String message) => _terminalSignals.any(message.contains);

/// Pure, unit-tested — 0002_storage_scoping.sql's RLS policy structurally
/// depends on this exact shape (`photos/{id}/...`, `signatures/{id}-...`);
/// a mismatch here silently locks every upload out.
String buildStoragePath(String key, String extension, {int? timestamp}) =>
    '$key-${timestamp ?? DateTime.now().microsecondsSinceEpoch}.$extension';

/// mark_item_done()'s arguments, from its queued payload. Pure, unit-tested.
///
/// p_answer goes only when there is one. Leaving a null out costs nothing —
/// the parameter defaults to null server-side — and it keeps two replays
/// working that sending it would break: a row queued by a build from before
/// answers existed (its payload has no p_answer key at all), and a database
/// without 0013, where PostgREST matches named arguments and no
/// mark_item_done takes a p_answer.
Map<String, dynamic> markItemDoneParams(Map<String, dynamic> payload) => {
  'p_item_id': payload['p_item_id'],
  'p_note': payload['p_note'],
  'p_answer': ?payload['p_answer'],
};

/// What `signature_url` and `photo_paths` actually contain, and how to render
/// any of it. Three shapes reach the UI through one column, which is why this
/// exists rather than a `startsWith('http')` check at the call site:
///
///  * a full https URL — what the admin web dashboard writes
///    (`.../object/public/checklist-media/signatures/<uuid>.png`);
///  * a bucket-relative path — what THIS app writes, because
///    submit_assignment/attach_item_photo store `p_signature_path` and
///    `p_storage_path` verbatim, and [buildStoragePath] produces
///    `signatures/<id>-<µs>.png`, no host and no scheme;
///  * an absolute device path — a photo or signature still sitting in the
///    outbox, not yet uploaded.
///
/// Returning null means "this is a local file, render it from disk". Treating
/// a bucket path as a local file is what made a submitted signature show the
/// grey placeholder: File('signatures/x.png') resolves against the process
/// working directory and never exists.
String? mediaUrl(String pathOrUrl) {
  if (pathOrUrl.startsWith('http')) return pathOrUrl;
  if (p.isAbsolute(pathOrUrl)) return null;
  return supabase.storage.from(kMediaBucket).getPublicUrl(pathOrUrl);
}

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

  /// In flight, if any. There are two triggers now — the connectivity listener
  /// above and the signature screen's own call — so two drains walking the
  /// same rows is reachable. That would upload the same photo twice under two
  /// different `buildStoragePath` timestamps, which defeats
  /// attach_item_photo()'s `not (p_storage_path = any(photo_paths))` guard and
  /// appends a duplicate. Nothing deletes from photo_paths (§8), so the
  /// pollution would be permanent. Single-flight, not a lock class.
  Future<void>? _draining;

  /// [watch] is the assignment whose outcome a human is waiting on, if any —
  /// only its failures are reported through [lastError], so flushing an older
  /// round's dead rows never gets blamed on the one being submitted now.
  Future<void> drain({String? watch}) =>
      _draining ??= _drain(watch).whenComplete(() => _draining = null);

  /// Why the last drain stopped, or null if it emptied the queue.
  ///
  /// The drain deliberately swallows its own failures — it is a background
  /// replay and must never throw into a caller — but that is exactly what made
  /// "submit does nothing" impossible to diagnose from the device. Callers
  /// that a human is waiting on (the signature screen) read this and say so.
  String? lastError;

  Future<void> _drain(String? watch) async {
    lastError = null;
    final ops = await _db.outboxOps();
    debugPrint('[outbox] draining ${ops.length} op(s)');

    for (final op in ops) {
      final id = op['id'] as String;
      final assignmentId = op['assignment_id'] as String;
      final name = op['op'] as String;
      final attempts = op['attempts'];
      final payload = op['payload'] as Map<String, dynamic>;
      try {
        await _replay(name, assignmentId, payload);
        await _db.dequeue(id);
        debugPrint('[outbox] ok $name ($assignmentId)');
      } catch (e) {
        // Classification lives HERE, in the loop, rather than inside one case
        // of _replay. That placement was the bug behind "submit does nothing":
        // isTerminalError was consulted only for submit_assignment, so an
        // 'Item not found' raised by mark_item_done — a row that can never
        // succeed — took the retryable branch and jammed the queue against a
        // stale tick forever, with every later round stacked behind it.
        final terminal =
            e is PostgrestTerminalException ||
            (e is PostgrestException && isTerminalError(e.message));

        if (terminal) {
          await _db.dequeue(id);
          debugPrint('[outbox] DROPPED $name ($assignmentId) — terminal: $e');
          // Only speak for the round the caller is waiting on. Flushing a
          // previous round's poison must not make this one's success screen
          // report an error that has nothing to do with it.
          if (assignmentId == watch) {
            lastError = 'The server rejected this round: $e';
          }
          continue; // the whole point — keep going, do not jam
        }

        await _db.bumpAttempts(id);
        // Retryable: a dropped connection, a 500. Stop and keep FIFO order,
        // but say so — a silently stuck queue is what made this invisible.
        lastError = '$name failed: $e';
        debugPrint(
          '[outbox] STUCK on $name ($assignmentId), attempt ${attempts + 1}: $e',
        );
        debugPrint(
          '[outbox] ${ops.length - ops.indexOf(op) - 1} op(s) behind it will not run',
        );
        return;
        // TODO(phase-4): a dropped op is still silent to any user who is not
        // standing on the signature screen — surface it via a local
        // notification keyed on assignmentId, worded per signal.
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
          params: markItemDoneParams(payload),
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
        // No local try/catch classifying the error: _drain does that for every
        // op now. Doing it here was what left mark_item_done unprotected.
        await supabase.rpc(
          'submit_assignment',
          params: {
            'p_assignment_id': assignmentId,
            'p_signature_path': signaturePath,
            'p_completed_at': payload['completed_at'],
          },
        );
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
    // Evidence lives in OS-purgeable directories — image_picker hands back a
    // raw cache path (detail_screen.dart's _takePhoto keeps no copy) and the
    // signature is written to getTemporaryDirectory(). Android reclaims both.
    //
    // A purged file must not take the retry path, and this is why: File() on a
    // missing path throws FileSystemException, which is not a
    // PostgrestException, so it falls to _drain's bare `catch (_)` — which
    // bumps attempts and RETURNS, stopping the whole walk. outboxOps() orders
    // by created_at across every assignment (despite its comment), so one dead
    // row from an old round blocks every round queued behind it, forever,
    // including the one the user just signed. Classifying it terminal drops
    // that row and lets the queue move.
    if (!File(localPath).existsSync()) throw PostgrestTerminalException();

    final path = buildStoragePath(key, extension);
    await supabase.storage
        .from(kMediaBucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(upsert: true), // idempotent on replay
        );
    return path;
  }
}

class PostgrestTerminalException implements Exception {}
