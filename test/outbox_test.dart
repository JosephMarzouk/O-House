import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/sync.dart';

// Pure-logic checks for the two things in the outbox path most likely to
// silently rot — see §11 of the plan. Network/db-touching FIFO replay is
// exercised manually per §11 item 7 until Phase 3 gives SyncService a
// fake client to test against.
void main() {
  group('isExpiredError', () {
    test('recognizes the RPC\'s expiry signal', () {
      expect(isExpiredError('ASSIGNMENT_EXPIRED'), isTrue);
      expect(isExpiredError('P0001: ASSIGNMENT_EXPIRED'), isTrue);
    });

    test('does not misclassify an unrelated error as terminal', () {
      expect(isExpiredError('INCOMPLETE: 2 item(s) not done'), isFalse);
      expect(isExpiredError('network timeout'), isFalse);
    });
  });

  group('buildStoragePath', () {
    test('photo path matches the shape 0002_storage_scoping.sql checks', () {
      final path = buildStoragePath('photos/abc-123/item-1', 'jpg', timestamp: 42);
      expect(path, 'photos/abc-123/item-1-42.jpg');
      expect(path, startsWith('photos/abc-123/'));
    });

    test('signature path matches the shape 0002_storage_scoping.sql checks', () {
      final path = buildStoragePath('signatures/abc-123', 'png', timestamp: 42);
      expect(path, 'signatures/abc-123-42.png');
      // The RLS draft matches `signatures/{id}-%` — the id must be
      // immediately followed by '-', not '/', or every signature upload
      // is silently rejected.
      expect(path, startsWith('signatures/abc-123-'));
    });

    test('two uploads a microsecond apart never collide', () {
      final a = buildStoragePath('photos/x/y', 'jpg', timestamp: 1);
      final b = buildStoragePath('photos/x/y', 'jpg', timestamp: 2);
      expect(a, isNot(equals(b)));
    });
  });
}
