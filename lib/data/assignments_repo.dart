import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/assignment.dart';
import '../models/assignment_item.dart';
import 'api_client.dart';
import 'local_db.dart';

const _uuid = Uuid();

/// Where unsent photos and signatures live: the app's documents folder,
/// which the OS does not purge the way it purges caches (LS-1). Payloads
/// store only the file NAME, so a moved app container cannot break them.
Future<Directory> evidenceDir() async {
  final d = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'evidence'),
  );
  await d.create(recursive: true);
  return d;
}

/// The cached round as the person should see it right now: the server's copy
/// with their queued work laid over it (answers, photos, a submit), and the
/// clock applied. Pure, unit-tested.
///
/// The overlay is recomputed on every read rather than written into the
/// cache, so a refresh from the server can never wipe work that has not been
/// sent yet, and a Dismissed op simply stops showing.
///
/// Expiry uses the view's own `deadline` against the server's clock (plan:
/// "Deadlines offline"), so a round whose window closed while the phone was
/// offline says so before anyone does work that will be refused. Only
/// pending and in_progress expire, exactly as effective_status does.
Assignment applyLocal(
  Assignment a,
  List<OutboxOp> ops, {
  required String evidencePath,
  required DateTime serverNow,
}) {
  var status = a.effectiveStatus;
  final deadline = a.deadline;
  if ((status == 'pending' || status == 'in_progress') &&
      deadline != null &&
      serverNow.isAfter(deadline)) {
    status = 'expired';
  }

  final mine = ops.where((o) => o.assignmentId == a.id).toList();
  if (mine.isEmpty && status == a.effectiveStatus) return a;

  final items = [
    for (final i in a.items)
      _itemWith(i, mine.where((o) => o.payload['itemId'] == i.id), evidencePath),
  ];
  final json = a.copyWithItems(items).toCacheJson();
  json['effective_status'] = status;
  for (final o in mine) {
    // A place scanned on this phone is open at once, offline included (Q5):
    // the scan was checked against the place's hash before it was queued.
    // If the server later answers bad_code (the sticker was replaced in the
    // meantime), the refresh after the drain brings the lock back.
    if (o.op == 'scan') json['unlocked'] = true;
    if (o.op == 'answer' && status == 'pending') status = 'in_progress';
    if (o.op == 'submit') {
      // Sent from this phone's point of view. The server may still answer
      // follow_up; the refresh after the drain replaces this with its verdict.
      status = 'submitted';
      json['signature_url'] = p.join(evidencePath, o.payload['file'] as String);
      json['submitted_at'] ??= o.payload['completedAt'];
      json['submit_note'] = o.payload['note'] ?? json['submit_note'];
    }
  }
  json['effective_status'] = status;
  return Assignment.fromJson(json);
}

AssignmentItem _itemWith(
  AssignmentItem i,
  Iterable<OutboxOp> ops,
  String evidencePath,
) {
  if (ops.isEmpty) return i;
  final json = i.toJson();
  for (final o in ops) {
    if (o.op == 'answer') {
      json['status'] = 'done';
      json['answer'] = o.payload['answer'] ?? json['answer'];
      json['reject_note'] = null;
    } else if (o.op == 'photo') {
      json['photo_paths'] = [
        ...(json['photo_paths'] as List? ?? const []),
        p.join(evidencePath, o.payload['file'] as String),
      ];
    }
  }
  return AssignmentItem.fromJson(json);
}

/// The one seam between screens and data (no screen touches the API or the
/// database directly). Reads are cache-first; writes only ever enqueue, and
/// SyncService sends them.
class AssignmentsRepo {
  AssignmentsRepo({
    required this.db,
    required this.api,
    required this.userId,
    required this.evidence,
  });

  final LocalDb db;
  final ApiClient api;
  final String userId;
  final Future<Directory> Function() evidence;

  static const _offsetKey = 'server_offset_ms';
  String get _refreshedKey => 'refreshed_at:$userId';

  // ---- reads ----------------------------------------------------------------

  /// What this person sees, from this phone alone: their cached rounds, their
  /// queued work on top, sorted by date. Never touches the network (LS-3).
  Future<List<Assignment>> cached() async {
    final rows = await db.rounds(userId);
    final ops = await db.ops(userId);
    final dir = (await evidence()).path;
    final now = DateTime.now().add(await serverOffset());
    return [
      for (final r in rows)
        applyLocal(Assignment.fromJson(r), ops, evidencePath: dir, serverNow: now),
    ]..sort(
      (a, b) => (a.scheduledDate ?? DateTime(0)).compareTo(
        b.scheduledDate ?? DateTime(0),
      ),
    );
  }

  /// How far the server's clock is ahead of this phone's, as of the last
  /// [refresh] (zero before the first). Added to the phone's time wherever a
  /// rule depends on the hour, so a phone set ahead can't open or keep a
  /// checklist it shouldn't.
  Future<Duration> serverOffset() async => Duration(
    milliseconds: int.tryParse(await db.getSetting(_offsetKey) ?? '') ?? 0,
  );

  /// `GET /assignments` into the cache: the whole offline window, so tomorrow's
  /// round is on the phone the night before. Throws when offline; the cache
  /// stays as it was.
  Future<void> refresh() async {
    final res = await api.get('/assignments') as Map<String, dynamic>;
    final serverTime = DateTime.parse(res['serverTime'] as String);
    final rounds = (res['assignments'] as List).cast<Map<String, dynamic>>();
    await db.replaceRounds(userId, rounds);
    await db.setSetting(
      _offsetKey,
      '${serverTime.difference(DateTime.now()).inMilliseconds}',
    );
    await db.setSetting(_refreshedKey, DateTime.now().toIso8601String());
  }

  /// When [refresh] last succeeded, for "Last updated 09:12" (LS-4).
  Future<DateTime?> refreshedAt() async {
    final v = await db.getSetting(_refreshedKey);
    return v == null ? null : DateTime.tryParse(v);
  }

  /// Signed links (1 h) for one round's photos and signature, keyed by the
  /// stored path. Online only; evidence not yet sent renders from its file.
  Future<Map<String, String?>> media(String assignmentId) async {
    final res = await api.get('/assignments/$assignmentId') as Map<String, dynamic>;
    return (res['media'] as Map).cast<String, String?>();
  }

  // ---- drafts: staged answers and photos survive the app being killed (LS-2)

  Future<RoundDraft> draft(String assignmentId) async =>
      RoundDraft.fromJson(await db.draft(userId, assignmentId));

  Future<void> saveDraft(String assignmentId, RoundDraft d) => d.isEmpty
      ? db.deleteDraft(userId, assignmentId)
      : db.saveDraft(userId, assignmentId, d.toJson());

  /// Copies a camera capture into the evidence folder under a new photo id,
  /// fixed here at capture so every retry of its upload writes the same
  /// object (SY-3). Compression already happened in the picker. A video clip
  /// keeps its own extension, `mp4`; that extension is the only thing that
  /// marks it as video on this side (the API reads the file's bytes).
  Future<String> keepPhoto(String capturedPath, {String ext = 'jpg'}) async {
    final id = _uuid.v4();
    await File(capturedPath).copy(p.join((await evidence()).path, '$id.$ext'));
    return id;
  }

  /// A staged photo's or clip's file, for display before it is sent. Drafts
  /// and queued ops hold the id alone, so the extension is found on disk.
  Future<String> photoPath(String photoId) async {
    final dir = (await evidence()).path;
    final video = p.join(dir, '$photoId.mp4');
    return File(video).existsSync() ? video : p.join(dir, '$photoId.jpg');
  }

  // ---- writes: enqueue only --------------------------------------------------

  /// Everything staged on the round, in the order the server needs: each
  /// item's photos before its answer, so requires_photo is met by the time
  /// the answer lands. Then the draft is cleared: from here the outbox owns it.
  Future<void> queueRound(String assignmentId, RoundDraft d) async {
    final itemIds = {...d.photos.keys, ...d.answers.keys};
    for (final itemId in itemIds) {
      for (final photoId in d.photos[itemId] ?? const <String>[]) {
        await db.enqueue(
          id: _uuid.v4(),
          userId: userId,
          assignmentId: assignmentId,
          op: 'photo',
          payload: {
            'itemId': itemId,
            'photoId': photoId,
            'file': p.basename(await photoPath(photoId)),
          },
        );
      }
      final answer = d.answers[itemId];
      if (answer != null) {
        await db.enqueue(
          id: _uuid.v4(),
          userId: userId,
          assignmentId: assignmentId,
          op: 'answer',
          payload: {'itemId': itemId, 'answer': answer},
        );
      }
    }
    await db.deleteDraft(userId, assignmentId);
  }

  /// A place's QR, scanned and matched on this phone: queued at once, so it
  /// goes before that checklist's answers (they only enter the outbox at
  /// Submit) and the drain's per-round order carries it through. The server
  /// checks the code again, logs the scan and claims the whole task for this
  /// person. [code] is the sticker's code, sent as read; the ids are fixed
  /// here so a replay is the same scan.
  Future<void> queueScan(String assignmentId, String code) => db.enqueue(
    id: _uuid.v4(),
    userId: userId,
    assignmentId: assignmentId,
    op: 'scan',
    payload: {
      'code': code,
      // With its offset, like completedAt: the scan log shows phone time.
      'scannedAt': isoWithOffset(DateTime.now()),
      'scanId': _uuid.v4(),
    },
  );

  // ---- the signature, reused across one task's places (QB) -----------------

  /// One row per person: the signatures they drew today, by task. A new day
  /// starts the map again, so it never grows past a day's tasks and an old
  /// signature is never offered the next morning.
  String get _signaturesKey => 'group_signatures:$userId';

  static String _day(DateTime t) => '${t.year}-${t.month}-${t.day}';

  /// Keeps [png] for [groupId]'s later places today.
  Future<void> rememberSignature(String groupId, Uint8List png) async {
    final today = _day(DateTime.now());
    final raw = await db.getSetting(_signaturesKey);
    final kept = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    final sigs = kept?['day'] == today
        ? Map<String, dynamic>.of(kept!['sigs'] as Map<String, dynamic>)
        : <String, dynamic>{};
    sigs[groupId] = base64Encode(png);
    await db.setSetting(_signaturesKey, jsonEncode({'day': today, 'sigs': sigs}));
  }

  /// The signature drawn today for another place of [groupId], or null.
  Future<Uint8List?> rememberedSignature(String groupId) async {
    final raw = await db.getSetting(_signaturesKey);
    if (raw == null) return null;
    final kept = jsonDecode(raw) as Map<String, dynamic>;
    if (kept['day'] != _day(DateTime.now())) return null;
    final b64 = (kept['sigs'] as Map<String, dynamic>)[groupId] as String?;
    return b64 == null ? null : base64Decode(b64);
  }

  /// The refusal code if this round has parked work, else null.
  Future<String?> parkedCode(String assignmentId) async {
    for (final o in await db.ops(userId)) {
      if (o.assignmentId == assignmentId && o.parked) return o.parkedCode;
    }
    return null;
  }

  /// SY-4: one pending submit per round. A second tap, or backing out of the
  /// pad and signing again, never queues a second one.
  Future<bool> hasPendingSubmit(String assignmentId) async => (await db.ops(
    userId,
  )).any((o) => o.assignmentId == assignmentId && o.op == 'submit');

  Future<void> submit(
    String assignmentId,
    Uint8List signaturePng, {
    String? note,
  }) async {
    if (await hasPendingSubmit(assignmentId)) return;
    final signatureId = _uuid.v4();
    final file = '$signatureId.png';
    await File(p.join((await evidence()).path, file)).writeAsBytes(signaturePng);
    await db.enqueue(
      id: _uuid.v4(),
      userId: userId,
      assignmentId: assignmentId,
      op: 'submit',
      payload: {
        'signatureId': signatureId,
        'file': file,
        // SY-7: with its offset, so the server can tell whether the work was
        // done before the deadline however late it syncs.
        'completedAt': isoWithOffset(DateTime.now()),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }
}

/// ISO-8601 with the local offset (`2026-09-23T14:05:00+03:00`). Dart's own
/// toIso8601String() drops the offset on a local time. Pure, unit-tested.
String isoWithOffset(DateTime t) {
  final o = t.timeZoneOffset;
  String two(int n) => n.toString().padLeft(2, '0');
  final sign = o.isNegative ? '-' : '+';
  final base = t.toIso8601String().split('.').first;
  return '$base$sign${two(o.inHours.abs())}:${two(o.inMinutes.abs() % 60)}';
}

/// What someone has staged on a round but not yet submitted.
class RoundDraft {
  RoundDraft({Map<String, String>? answers, Map<String, List<String>>? photos})
    : answers = answers ?? {},
      photos = photos ?? {};

  /// itemId → the normalized answer.
  final Map<String, String> answers;

  /// itemId → photo ids, each a file in the evidence folder.
  final Map<String, List<String>> photos;

  bool get isEmpty => answers.isEmpty && photos.isEmpty;

  factory RoundDraft.fromJson(Map<String, dynamic>? j) => RoundDraft(
    answers: (j?['answers'] as Map?)?.cast<String, String>() ?? {},
    photos: {
      for (final e in ((j?['photos'] as Map?) ?? {}).entries)
        e.key as String: (e.value as List).cast<String>(),
    },
  );

  Map<String, dynamic> toJson() => {'answers': answers, 'photos': photos};
}
