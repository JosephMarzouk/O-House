import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/assignments_repo.dart';
import 'package:o_house/data/local_db.dart';
import 'package:o_house/data/sync.dart';

// Pure-logic checks for the things in the outbox path most likely to
// silently rot — see §11 of the plan. Network/db-touching FIFO replay is
// exercised manually per §11 item 7 until Phase 3 gives SyncService a
// fake client to test against.

/// Records what the repo queues instead of writing it to sqflite, which has
/// no test binding. `implements` rather than a subclass: LocalDb's only
/// constructor is private. Everything but enqueue is left unimplemented.
class _CapturingDb implements LocalDb {
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<void> enqueue({
    required String id,
    required String assignmentId,
    required String op,
    required Map<String, dynamic> payload,
  }) async => payloads.add(payload);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The answer is the whole point of 0013's mark_item_done — a queue that
  // quietly dropped it would flag every rule item on the server as unanswered
  // while the device showed it answered.
  group('mark_item_done answers', () {
    test('the queued op carries the answer', () async {
      final db = _CapturingDb();
      await AssignmentsRepo(db).markItemDone('a1', 'i1', answer: '2.5');

      expect(db.payloads.single, {
        'p_item_id': 'i1',
        'p_note': null,
        'p_answer': '2.5',
      });
    });

    test('replay sends the answer', () {
      expect(
        markItemDoneParams({
          'p_item_id': 'i1',
          'p_note': null,
          'p_answer': 'no',
        }),
        {'p_item_id': 'i1', 'p_note': null, 'p_answer': 'no'},
      );
    });

    test('replay leaves a missing answer out of the call entirely', () {
      // A row queued by a build from before answers existed has no key at
      // all; naming p_answer against a pre-0013 database matches no function.
      expect(markItemDoneParams({'p_item_id': 'i1', 'p_note': null}), {
        'p_item_id': 'i1',
        'p_note': null,
      });
      expect(
        markItemDoneParams({
          'p_item_id': 'i1',
          'p_note': 'x',
          'p_answer': null,
        }),
        {'p_item_id': 'i1', 'p_note': 'x'},
      );
    });
  });

  group('isTerminalError', () {
    test('recognizes every signal the RPC will keep raising', () {
      expect(isTerminalError('ASSIGNMENT_EXPIRED'), isTrue);
      expect(isTerminalError('P0001: ASSIGNMENT_EXPIRED'), isTrue);
      expect(isTerminalError('EMPTY_SUBMISSION: no item(s) done'), isTrue);
      expect(
        isTerminalError('MISSING_PHOTO: 1 item(s) require a photo'),
        isTrue,
      );
      // Pre-0006 databases still raise this one; see _terminalSignals.
      expect(isTerminalError('INCOMPLETE: 2 item(s) not done'), isTrue);
    });

    // These three jammed a real device. mark_item_done raised 'Item not found'
    // for a tick whose row had been deleted; the classifier was consulted only
    // inside submit_assignment, so it was retried forever and every op behind
    // it — including the round the user was signing — never ran.
    test('recognizes the per-item rejections that used to jam the queue', () {
      expect(isTerminalError('Item not found'), isTrue);
      expect(isTerminalError('Not authorized'), isTrue);
      expect(isTerminalError('Assignment is closed'), isTrue);
      expect(isTerminalError('Assignment not found'), isTrue);
    });

    test('leaves a retryable failure retryable', () {
      // The whole point of the split: a dropped connection must go back on
      // the queue, not be thrown away as a permanent rejection.
      expect(isTerminalError('network timeout'), isFalse);
      expect(isTerminalError('SocketException: Connection refused'), isFalse);
      // Over-matching is the failure mode worse than a jam — a terminal
      // verdict deletes a signed round. 'not found' on its own must not match,
      // or a transient 404 from the gateway would throw the work away.
      expect(isTerminalError('404 not found'), isFalse);
      expect(isTerminalError('Service Unavailable'), isFalse);
    });
  });

  // signature_url and photo_paths carry three different shapes depending on
  // who wrote the row, and getting this wrong is invisible — the image just
  // falls back to the grey placeholder, which also happens for a dozen
  // legitimate reasons. Only the two cases that need no Supabase client are
  // asserted; the bucket-path branch calls getPublicUrl and is covered by the
  // manual check, since initializing Supabase for one string is not worth it.
  group('mediaUrl', () {
    test('passes a dashboard-written URL through untouched', () {
      const url =
          'https://x.supabase.co/storage/v1/object/public/checklist-media/'
          'signatures/abc.png';
      expect(mediaUrl(url), url);
    });

    test('treats an absolute device path as a local file', () {
      // Still in the outbox, not yet uploaded — null means "render from disk".
      expect(mediaUrl('/data/user/0/com.example/cache/sig.png'), isNull);
      expect(mediaUrl(r'C:\Users\x\AppData\Local\Temp\sig.png'), isNull);
    });
  });

  group('buildStoragePath', () {
    test('photo path matches the shape 0002_storage_scoping.sql checks', () {
      final path = buildStoragePath(
        'photos/abc-123/item-1',
        'jpg',
        timestamp: 42,
      );
      expect(path, 'photos/abc-123/item-1-42.jpg');
      expect(path, startsWith('photos/abc-123/'));
    });

    test(
      'signature path matches the shape 0002_storage_scoping.sql checks',
      () {
        final path = buildStoragePath(
          'signatures/abc-123',
          'png',
          timestamp: 42,
        );
        expect(path, 'signatures/abc-123-42.png');
        // The RLS draft matches `signatures/{id}-%` — the id must be
        // immediately followed by '-', not '/', or every signature upload
        // is silently rejected.
        expect(path, startsWith('signatures/abc-123-'));
      },
    );

    test('two uploads a microsecond apart never collide', () {
      final a = buildStoragePath('photos/x/y', 'jpg', timestamp: 1);
      final b = buildStoragePath('photos/x/y', 'jpg', timestamp: 2);
      expect(a, isNot(equals(b)));
    });
  });
}
