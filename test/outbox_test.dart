import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:o_house/data/api_client.dart';
import 'package:o_house/data/assignments_repo.dart';
import 'package:o_house/data/local_db.dart';
import 'package:o_house/data/sync.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/data/auth_service.dart';

// The outbox is where work gets lost, so it is tested against fakes rather
// than trusted: an in-memory LocalDb (sqflite has no test binding) and an
// ApiClient whose answers each test scripts.

/// In-memory stand-in for the parts of LocalDb the drain uses. `implements`
/// rather than extends, so a method the drain starts using without a fake
/// fails loudly here.
class _MemDb implements LocalDb {
  final rows = <OutboxOp>[];
  var _seq = 0;

  void add(
    String id,
    String assignmentId,
    String op, {
    String user = 'u1',
    Map<String, dynamic> payload = const {},
  }) => rows.add(
    OutboxOp(
      seq: ++_seq,
      id: id,
      userId: user,
      assignmentId: assignmentId,
      op: op,
      payload: payload,
      attempts: 0,
      parkedCode: null,
      parkedMessage: null,
    ),
  );

  OutboxOp _copy(OutboxOp o, {String? code, String? message, bool clear = false}) =>
      OutboxOp(
        seq: o.seq,
        id: o.id,
        userId: o.userId,
        assignmentId: o.assignmentId,
        op: o.op,
        payload: o.payload,
        attempts: o.attempts,
        parkedCode: clear ? null : code ?? o.parkedCode,
        parkedMessage: clear ? null : message ?? o.parkedMessage,
      );

  @override
  Future<List<OutboxOp>> ops(String userId) async =>
      rows.where((o) => o.userId == userId).toList();

  @override
  Future<void> dequeue(String id) async => rows.removeWhere((o) => o.id == id);

  @override
  Future<void> bumpAttempts(String id) async {}

  @override
  Future<void> park(String id, String code, String message) async {
    final i = rows.indexWhere((o) => o.id == id);
    rows[i] = _copy(rows[i], code: code, message: message);
  }

  @override
  Future<void> unpark(String id) async {
    final i = rows.indexWhere((o) => o.id == id);
    rows[i] = _copy(rows[i], clear: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers each request by its path; records the order requests were made.
class _FakeApi extends ApiClient {
  _FakeApi(this.answer)
    : super(
        baseUrl: 'http://api',
        club: 'c',
        token: () => 't',
        refreshSession: () async => false,
      );

  /// Throws to fail the request; returns to succeed.
  final FutureOr<void> Function(String path) answer;
  final calls = <String>[];

  @override
  Future<Object?> post(String path, {Object? json, String? key}) async {
    calls.add(path);
    await answer(path);
    return null;
  }

  @override
  Future<Object?> upload(
    String path, {
    required File file,
    required Map<String, String> fields,
    required String key,
  }) async {
    calls.add(path);
    await answer(path);
    return null;
  }
}

void main() {
  late Directory evidence;
  setUp(() => evidence = Directory.systemTemp.createTempSync('evidence'));
  tearDown(() => evidence.deleteSync(recursive: true));

  SyncService sync(_MemDb db, _FakeApi api, {Future<void> Function()? onSent}) =>
      SyncService(
        db: db,
        api: api,
        userId: 'u1',
        evidenceDir: () async => evidence,
        onSent: onSent,
      );

  group('classifyResponse: the refusal contract as the phone reads it', () {
    test('2xx is applied', () {
      expect(classifyResponse(204, ''), isNull);
      expect(classifyResponse(200, '{"a":1}'), {'a': 1});
    });

    test('only a 422 that says refused is a refusal', () {
      expect(
        () => classifyResponse(422, '{"refused":true,"code":"ASSIGNMENT_EXPIRED","message":"x"}'),
        throwsA(isA<ApiRefused>().having((e) => e.code, 'code', 'ASSIGNMENT_EXPIRED')),
      );
      // A 422 without the flag is not ours to drop.
      expect(() => classifyResponse(422, '{"code":"X"}'), throwsA(isA<ApiUnavailable>()));
      expect(() => classifyResponse(422, 'not json'), throwsA(isA<ApiUnavailable>()));
    });

    test('everything else retries: a bad deploy must never wipe queues', () {
      for (final s in [400, 403, 404, 409, 500, 503]) {
        expect(() => classifyResponse(s, '{}'), throwsA(isA<ApiUnavailable>()));
      }
    });
  });

  group('ApiClient', () {
    test('a 401 refreshes the session once, then retries with the new token', () async {
      var token = 'old';
      final seen = <String?>[];
      final client = MockClient((req) async {
        seen.add(req.headers['authorization']);
        expect(req.headers['x-club'], 'ohouse');
        expect(req.headers['idempotency-key'], 'k1');
        return req.headers['authorization'] == 'Bearer new'
            ? http.Response('', 204)
            : http.Response('{}', 401);
      });
      final api = ApiClient(
        baseUrl: 'http://api',
        club: 'ohouse',
        token: () => token,
        refreshSession: () async {
          token = 'new';
          return true;
        },
        client: client,
      );
      await api.post('/x', key: 'k1');
      expect(seen, ['Bearer old', 'Bearer new']);
    });

    test('no response at all stops everything; a status stops one round', () async {
      final api = ApiClient(
        baseUrl: 'http://api',
        club: 'c',
        token: () => 't',
        refreshSession: () async => false,
        client: MockClient((_) async => throw const SocketException('down')),
      );
      await expectLater(
        api.get('/x'),
        throwsA(isA<ApiUnavailable>().having((e) => e.stopsAll, 'stopsAll', true)),
      );
      expect(ApiUnavailable(503).stopsAll, isFalse);
      expect(ApiUnavailable(401).stopsAll, isTrue);
    });
  });

  group('SyncService drain', () {
    test('per round, in queue order; a 503 stops only its own round', () async {
      final db = _MemDb()
        ..add('1', 'A', 'answer', payload: {'itemId': 'i1', 'answer': 'yes'})
        ..add('2', 'B', 'answer', payload: {'itemId': 'i2', 'answer': 'no'})
        ..add('3', 'A', 'answer', payload: {'itemId': 'i3', 'answer': 'yes'});
      final api = _FakeApi((path) {
        if (path.contains('/A/items/i1/')) throw ApiUnavailable(503);
      });
      await sync(db, api).drain();

      expect(api.calls, ['/assignments/A/items/i1/answer', '/assignments/B/items/i2/answer']);
      expect(db.rows.map((o) => o.id), ['1', '3']); // A waits whole, in order
    });

    test('no response stops the whole drain', () async {
      final db = _MemDb()
        ..add('1', 'A', 'answer', payload: {'itemId': 'i1'})
        ..add('2', 'B', 'answer', payload: {'itemId': 'i2'});
      final api = _FakeApi((_) => throw ApiUnavailable(null));
      final s = sync(db, api);
      await s.drain();
      expect(api.calls, hasLength(1));
      expect(db.rows, hasLength(2));
      expect(s.status.value.offline, isTrue);
      s.dispose();
    });

    test('a refusal parks the op, keeps it, and holds the rest of its round', () async {
      final db = _MemDb()
        ..add('1', 'A', 'answer', payload: {'itemId': 'i1'})
        ..add('2', 'A', 'answer', payload: {'itemId': 'i2'});
      final api = _FakeApi((path) {
        if (path.contains('i1')) throw ApiRefused('ASSIGNMENT_EXPIRED', 'x');
      });
      final s = sync(db, api);
      await s.drain();
      expect(db.rows.map((o) => (o.id, o.parkedCode)), [('1', 'ASSIGNMENT_EXPIRED'), ('2', null)]);
      expect(s.status.value.parked, 1);

      // Held: a later drain does not let op 2 overtake the parked op 1.
      await s.drain();
      expect(api.calls, hasLength(1));

      // Retry sends both, in order, once the supervisor extended the round.
      api.calls.clear();
      final ok = _FakeApi((_) {});
      final s2 = sync(db, ok);
      await s2.retry('1');
      expect(ok.calls, ['/assignments/A/items/i1/answer', '/assignments/A/items/i2/answer']);
      expect(db.rows, isEmpty);
    });

    test('evidence is deleted only after a 2xx', () async {
      File('${evidence.path}/p1.jpg').writeAsStringSync('jpg');
      File('${evidence.path}/p2.jpg').writeAsStringSync('jpg');
      final db = _MemDb()
        ..add('1', 'A', 'photo', payload: {'itemId': 'i', 'photoId': 'p1', 'file': 'p1.jpg'})
        ..add('2', 'B', 'photo', payload: {'itemId': 'i', 'photoId': 'p2', 'file': 'p2.jpg'});
      await sync(db, _FakeApi((path) {
        if (path.contains('/B/')) throw ApiUnavailable(503);
      })).drain();
      expect(File('${evidence.path}/p1.jpg').existsSync(), isFalse);
      expect(File('${evidence.path}/p2.jpg').existsSync(), isTrue);
    });

    test('a purged evidence file is parked as MISSING_FILE, not retried forever', () async {
      final db = _MemDb()
        ..add('1', 'A', 'submit', payload: {'signatureId': 's', 'file': 'gone.png', 'completedAt': 'x'});
      final api = _FakeApi((_) {});
      await sync(db, api).drain();
      expect(db.rows.single.parkedCode, 'MISSING_FILE');
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, ['/sync/refusals']); // reported, never uploaded
    });

    test("only the signed-in user's ops are sent (shared phone)", () async {
      final db = _MemDb()
        ..add('1', 'A', 'answer', user: 'someone-else', payload: {'itemId': 'i'})
        ..add('2', 'B', 'answer', payload: {'itemId': 'j'});
      final api = _FakeApi((_) {});
      await sync(db, api).drain();
      expect(api.calls, ['/assignments/B/items/j/answer']);
      expect(db.rows.single.userId, 'someone-else');
    });

    test('a drain requested mid-run runs again, so a new op is not stranded', () async {
      final db = _MemDb()..add('1', 'A', 'answer', payload: {'itemId': 'i1'});
      final gate = Completer<void>();
      final api = _FakeApi((path) => path.contains('i1') ? gate.future : null);
      final s = sync(db, api);

      final first = s.drain();
      await Future<void>.delayed(Duration.zero);
      db.add('2', 'A', 'answer', payload: {'itemId': 'i2'}); // queued during the drain
      final second = s.drain(); // joins the running one, sets rerun
      gate.complete();
      await Future.wait([first, second]);

      expect(api.calls, ['/assignments/A/items/i1/answer', '/assignments/A/items/i2/answer']);
      expect(db.rows, isEmpty);
    });

    test('after anything lands, the rounds are refreshed', () async {
      final db = _MemDb()..add('1', 'A', 'answer', payload: {'itemId': 'i'});
      var refreshed = 0;
      await sync(db, _FakeApi((_) {}), onSent: () async => refreshed++).drain();
      expect(refreshed, 1);
    });
  });

  test('backoff: 5 s doubling, capped at 5 min', () {
    expect(backoff(1), const Duration(seconds: 5));
    expect(backoff(2), const Duration(seconds: 10));
    expect(backoff(4), const Duration(seconds: 40));
    expect(backoff(20), const Duration(minutes: 5));
  });

  group('applyLocal: queued work shows before it is sent', () {
    Assignment round({String status = 'in_progress', DateTime? deadline}) =>
        Assignment.fromJson({
          'id': 'A',
          'inspector_id': 'u1',
          'status': status,
          'effective_status': status,
          'deadline': deadline?.toIso8601String(),
          'items': [
            {'id': 'i1', 'assignment_id': 'A', 'status': 'pending', 'photo_paths': <String>[]},
          ],
        });
    OutboxOp op(String kind, Map<String, dynamic> payload) => OutboxOp(
      seq: 1,
      id: kind,
      userId: 'u1',
      assignmentId: 'A',
      op: kind,
      payload: payload,
      attempts: 0,
      parkedCode: null,
      parkedMessage: null,
    );
    final now = DateTime.utc(2026, 9, 23, 12);

    test('answers, photos and the submit are laid over the cached round', () {
      final a = applyLocal(
        round(),
        [
          op('photo', {'itemId': 'i1', 'file': 'p.jpg'}),
          op('answer', {'itemId': 'i1', 'answer': 'yes'}),
          op('submit', {'file': 's.png', 'completedAt': '2026-09-23T14:00:00+03:00'}),
        ],
        evidencePath: '/ev',
        serverNow: now,
      );
      expect(a.items.single.status, 'done');
      expect(a.items.single.answer, 'yes');
      expect(a.items.single.photoPaths.single, endsWith('p.jpg'));
      expect(a.effectiveStatus, 'submitted');
      expect(a.signatureUrl, endsWith('s.png'));
    });

    test("a window that closed offline shows as expired, by the server's clock", () {
      final past = now.subtract(const Duration(minutes: 1));
      expect(applyLocal(round(deadline: past), [], evidencePath: '/ev', serverNow: now).effectiveStatus, 'expired');
      expect(
        applyLocal(round(status: 'follow_up', deadline: past), [], evidencePath: '/ev', serverNow: now).effectiveStatus,
        'follow_up', // never clock-expired
      );
    });
  });

  test('completedAt carries its offset (SY-7)', () {
    final s = isoWithOffset(DateTime(2026, 9, 23, 14, 5, 9));
    expect(s, matches(RegExp(r'^2026-09-23T14:05:09[+-]\d\d:\d\d$')));
  });

  test('RoundDraft survives the round trip through the database', () {
    final d = RoundDraft(answers: {'i1': 'yes'}, photos: {'i1': ['p1', 'p2']});
    final back = RoundDraft.fromJson(d.toJson());
    expect(back.answers, {'i1': 'yes'});
    expect(back.photos, {'i1': ['p1', 'p2']});
    expect(RoundDraft.fromJson(null).isEmpty, isTrue);
  });

  test('a typed phone is remembered in the form the API stores', () {
    expect(normalizePhone('+201001234567'), '+201001234567');
    expect(normalizePhone('+20 0100 123 4567'), '+201001234567');
    expect(normalizePhone('01001234567'), '+201001234567');
  });
}
