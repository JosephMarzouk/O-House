import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';
import 'local_db.dart';

/// What the banner shows (SY-5).
@immutable
class SyncStatus {
  const SyncStatus({
    this.waiting = 0,
    this.parked = 0,
    this.sending = false,
    this.sent = 0,
    this.total = 0,
    this.offline = false,
  });

  /// Ops not yet accepted, parked ones excluded.
  final int waiting;

  /// Ops the API refused: "needs attention", with Retry / Dismiss.
  final int parked;
  final bool sending;

  /// Progress of the drain in flight: "uploading [sent] of [total]".
  final int sent;
  final int total;

  /// The last attempt got no response at all.
  final bool offline;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.waiting == waiting &&
      other.parked == parked &&
      other.sending == sending &&
      other.sent == sent &&
      other.total == total &&
      other.offline == offline;

  @override
  int get hashCode => Object.hash(waiting, parked, sending, sent, total, offline);
}

/// SY-1: 5 s, doubling, capped at 5 min.
Duration backoff(int failures) {
  if (failures <= 0) return Duration.zero;
  final s = 5 * (1 << (failures - 1).clamp(0, 6));
  return Duration(seconds: s > 300 ? 300 : s);
}

/// Answered failures after which a change stops retrying and waits for the
/// person instead (SYNC-Q1: never retry forever). At the 5-minute backoff cap
/// that is about two hours of a server that keeps refusing.
const maxAttempts = 24;

/// SYNC-Q1 / F-12: whether a failed send should park now, and with what.
/// null = keep retrying with backoff.
///  * 400 / 403 / 404 / 409 park at once: the server has answered, and asking
///    again won't change its mind (a deactivated account's 403 included).
///  * Any other answer (503, 429, an unexpected 5xx) counts toward
///    [maxAttempts]; the 24th in a row parks as STILL_FAILING.
///  * No response, or an expired session (401), doesn't count: that is the
///    phone being offline or signed out, not the change failing, and staff
///    working two hours in a basement must not come back to "needs attention".
/// Parked work is never deleted without the person's Dismiss.
@visibleForTesting
({String code, String message})? parkFor(ApiUnavailable e, int attemptsBefore) {
  final s = e.status;
  if (s == null || s == 401 || s == 426) return null;
  if (const {400, 403, 404, 409}.contains(s)) {
    final body = _jsonObject(e.detail);
    return (
      code: body?['code'] is String ? body!['code'] as String : 'HTTP_$s',
      message: body?['message'] is String ? body!['message'] as String : 'The server refused this change ($s)',
    );
  }
  if (attemptsBefore + 1 >= maxAttempts) {
    return (code: 'STILL_FAILING', message: 'The server kept refusing this change ($s, $maxAttempts tries)');
  }
  return null;
}

/// Whether a failure is one of the answered ones [parkFor] counts.
/// An outdated app (426) waits for the update; it isn't the change failing.
bool _counts(ApiUnavailable e) => e.status != null && e.status != 401 && e.status != 426;

Map<String, dynamic>? _jsonObject(Object? detail) {
  if (detail is! String) return null;
  try {
    final j = jsonDecode(detail);
    return j is Map<String, dynamic> ? j : null;
  } on FormatException {
    return null;
  }
}

/// Raised for evidence the OS or the user deleted before it was sent. The
/// phone decides this refusal itself, so it is also reported to the API.
class _MissingFile implements Exception {}

/// The outbox drain (SY-1, SY-2, SY-6).
///
///  * **Order:** per round, in the order the ops were queued, so photos and
///    answers land before that round's submit. Rounds are independent: a 503
///    on one stops only that round. No response at all stops everything.
///  * **One drain at a time.** A drain requested mid-run sets [_rerun] and
///    runs again once the current one ends, so an op queued during a drain is
///    never left behind until the next trigger.
///  * **Refusals park, never vanish.** The op and its evidence stay; the rest
///    of that round waits behind it, because order within a round is the
///    contract. Retry un-parks; Dismiss deletes it and its evidence.
///  * **Only the signed-in user's ops** are ever sent (LS-5).
///  * **Evidence is deleted only after a 2xx** (LS-1).
class SyncService {
  SyncService({
    required this.db,
    required this.api,
    required this.userId,
    required this.evidenceDir,
    this.onSent,
  });

  final LocalDb db;
  final ApiClient api;
  final String userId;
  final Future<Directory> Function() evidenceDir;

  /// After any drain that got something accepted: refresh the rounds, so the
  /// server's verdicts (done or follow_up) replace the optimistic ones.
  final Future<void> Function()? onSent;

  final status = ValueNotifier(const SyncStatus());

  Future<void>? _running;
  bool _rerun = false;
  int _failures = 0;
  Timer? _retry;
  bool _disposed = false;

  /// Safe to call from anywhere, as often as wanted (app start, resume,
  /// reconnect, after every enqueue, the backoff timer).
  Future<void> drain() {
    if (_disposed) return Future.value();
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _rerun = false;
      await _drainOnce();
    } while (_rerun && !_disposed);
  }

  Future<void> _drainOnce() async {
    _retry?.cancel();
    final all = await db.ops(userId);
    final parkedRounds = {
      for (final o in all)
        if (o.parked) o.assignmentId,
    };
    // A round with a parked op waits whole: its later ops must not overtake it.
    final todo = [
      for (final o in all)
        if (!parkedRounds.contains(o.assignmentId)) o,
    ];
    var parked = all.where((o) => o.parked).length;
    var waiting = all.length - parked;
    if (todo.isEmpty) {
      status.value = SyncStatus(waiting: waiting, parked: parked);
      return;
    }

    final stopped = <String>{}; // rounds that hit a retryable failure
    var sent = 0;
    var retryable = false;
    var offline = false;
    status.value = SyncStatus(
      waiting: waiting,
      parked: parked,
      sending: true,
      total: todo.length,
    );

    for (final op in todo) {
      if (_disposed) return;
      if (stopped.contains(op.assignmentId)) continue;
      try {
        await _send(op);
        await db.dequeue(op.id);
        await _deleteEvidence(op);
        sent++;
        waiting--;
      } on ApiRefused catch (e) {
        await db.park(op.id, e.code, e.message);
        stopped.add(op.assignmentId);
        parked++;
        waiting--;
        debugPrint('[outbox] parked ${op.op} ${op.id}: ${e.code}');
      } on _MissingFile {
        const code = 'MISSING_FILE';
        const message = 'The photo or signature file is no longer on this phone';
        await db.park(op.id, code, message);
        stopped.add(op.assignmentId);
        parked++;
        waiting--;
        unawaited(_reportMissing(op, code, message));
      } on ApiUnavailable catch (e) {
        final park = parkFor(e, op.attempts);
        if (park != null) {
          await db.park(op.id, park.code, park.message);
          stopped.add(op.assignmentId);
          parked++;
          waiting--;
          debugPrint('[outbox] parked ${op.op} ${op.id}: ${park.code}');
        } else {
          if (_counts(e)) await db.bumpAttempts(op.id);
          retryable = true;
          debugPrint('[outbox] ${op.op} ${op.id} will retry: $e');
          if (e.stopsAll) {
            offline = e.status == null;
            break;
          }
          stopped.add(op.assignmentId);
        }
      }
      status.value = SyncStatus(
        waiting: waiting,
        parked: parked,
        sending: true,
        sent: sent,
        total: todo.length,
      );
    }

    status.value = SyncStatus(waiting: waiting, parked: parked, offline: offline);
    if (retryable) {
      _failures++;
      _retry = Timer(backoff(_failures), drain);
    } else {
      _failures = 0;
    }
    if (sent > 0 && onSent != null) {
      try {
        await onSent!();
      } catch (e) {
        debugPrint('[outbox] refresh after drain failed: $e');
      }
    }
  }

  Future<void> _send(OutboxOp op) async {
    final a = op.assignmentId;
    final pl = op.payload;
    switch (op.op) {
      // A place's QR. A 200 whatever the verdict ('scan' or 'bad_code'):
      // enforcement is the app's, the server only logs (Q10), so a bad code
      // never parks the answers queued behind it.
      case 'scan':
        await api.post(
          '/assignments/$a/scan',
          json: {
            'code': pl['code'],
            'scannedAt': pl['scannedAt'],
            'scanId': pl['scanId'],
          },
          key: op.id,
        );
      case 'answer':
        await api.post(
          '/assignments/$a/items/${pl['itemId']}/answer',
          json: {'answer': ?pl['answer'], 'note': ?pl['note']},
          key: op.id,
        );
      case 'photo':
        await api.upload(
          '/assignments/$a/items/${pl['itemId']}/photos',
          file: await _evidence(pl['file'] as String),
          fields: {'photoId': pl['photoId'] as String},
          key: op.id,
        );
      case 'submit':
        await api.upload(
          '/assignments/$a/submit',
          file: await _evidence(pl['file'] as String),
          fields: {
            'signatureId': pl['signatureId'] as String,
            'completedAt': pl['completedAt'] as String,
            'note': ?pl['note'] as String?,
          },
          key: op.id,
        );
      default:
        // A row this build cannot read: park it rather than lose it.
        throw ApiRefused('UNKNOWN_OP', 'Unknown outbox op ${op.op}');
    }
  }

  Future<File> _evidence(String name) async {
    final f = File(p.join((await evidenceDir()).path, name));
    if (!f.existsSync()) throw _MissingFile();
    return f;
  }

  Future<void> _deleteEvidence(OutboxOp op) async {
    final name = op.payload['file'] as String?;
    if (name == null) return;
    try {
      await File(p.join((await evidenceDir()).path, name)).delete();
    } catch (_) {
      // Already gone. The op landed, which is all that mattered.
    }
  }

  Future<void> _reportMissing(OutboxOp op, String code, String message) async {
    try {
      await api.post(
        '/sync/refusals',
        json: {
          'op': op.op,
          'code': code,
          'message': message,
          'assignmentId': op.assignmentId,
          'itemId': ?op.payload['itemId'],
        },
        key: op.id,
      );
    } catch (_) {
      // Best effort: the phone shows it either way.
    }
  }

  /// Retry a parked op: same id, same evidence, back in its place in the round.
  Future<void> retry(String opId) async {
    await db.unpark(opId);
    _failures = 0;
    await drain();
  }

  /// Dismiss a parked op. The person has seen it; its evidence goes with it.
  Future<void> dismiss(OutboxOp op) async {
    await db.dequeue(op.id);
    await _deleteEvidence(op);
    await drain();
  }

  /// Stops timers and further drains. [status] is left undisposed on
  /// purpose: a drain still finishing may set it once more, and a notifier
  /// with no listeners is simply collected.
  void dispose() {
    _disposed = true;
    _retry?.cancel();
  }
}
