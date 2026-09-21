import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/models/assignment_item.dart';

/// The two rules on these screens that can be wrong without looking wrong.
///
/// `tabFor` decides which of three tabs an assignment appears under, and a
/// bug there hides work rather than showing an error — a round that lands in
/// no tab at all is simply never done. It is asserted as a total partition
/// for that reason.
///
/// `canSubmitStaged` is the partial-submit gate. It deliberately differs from
/// Assignment.canSubmit (all items done) and from the server's contract, so
/// there is nothing else in the codebase to check it against.
///
/// Layout, the camera, and the ink headers are left to manual verification.
AssignmentItem _item(
  String id, {
  String status = 'pending',
  bool requiresPhoto = false,
  List<String> photoPaths = const [],
}) => AssignmentItem(
  id: id,
  assignmentId: 'a1',
  textEn: 'Pool deck',
  textAr: 'حافة المسبح',
  type: 'yesno',
  critical: false,
  requiresPhoto: requiresPhoto,
  sortOrder: 0,
  status: status,
  doneAt: null,
  note: null,
  rejectNote: null,
  photoPaths: photoPaths,
);

Assignment _a({
  DateTime? scheduledDate,
  String titleEn = 'Morning round',
  String titleAr = 'الجولة الصباحية',
  String? siteNameEn = 'Swimming pool',
  String? siteNameAr = 'حمام السباحة',
  List<AssignmentItem> items = const [],
}) => Assignment(
  id: 'a1',
  assigneeId: 'u1',
  assigneeName: 'Joseph Marzouk',
  titleEn: titleEn,
  titleAr: titleAr,
  siteNameEn: siteNameEn,
  siteNameAr: siteNameAr,
  scheduledDate: scheduledDate,
  windowStart: '07:00:00',
  windowEnd: '11:00:00',
  status: 'pending',
  effectiveStatus: 'pending',
  wasExtended: false,
  extensionNote: null,
  submittedAt: null,
  completedAt: null,
  lateSync: false,
  signatureUrl: null,
  reviewNote: null,
  items: items,
);

void main() {
  final now = DateTime(2026, 9, 3, 14, 30);

  group('tabFor', () {
    test('buckets by scheduled day, ignoring the time of day', () {
      // 06:00 is behind `now`, but it is still today's round.
      expect(
        tabFor(_a(scheduledDate: DateTime(2026, 9, 3, 6)), now),
        TaskTab.today,
      );
      expect(
        tabFor(_a(scheduledDate: DateTime(2026, 9, 4)), now),
        TaskTab.upcoming,
      );
      expect(
        tabFor(_a(scheduledDate: DateTime(2026, 9, 2)), now),
        TaskTab.history,
      );
    });

    test('a closed round scheduled today stays in Today, not History', () {
      // The design's Today tab shows submitted and rejected rounds beside the
      // outstanding ones — it answers "what did my day look like".
      final submitted = _a(scheduledDate: DateTime(2026, 9, 3));
      expect(tabFor(submitted, now), TaskTab.today);
    });

    test('an assignment with no date is never dropped', () {
      expect(tabFor(_a(), now), TaskTab.today);
    });
  });

  group('matchesQuery', () {
    final a = _a();

    test('an empty or blank query matches everything', () {
      expect(matchesQuery(a, ''), isTrue);
      expect(matchesQuery(a, '   '), isTrue);
    });

    test('matches the site name, not just the title', () {
      expect(matchesQuery(a, 'pool'), isTrue);
      expect(matchesQuery(a, 'MORNING'), isTrue);
      expect(matchesQuery(a, 'padel'), isFalse);
    });

    test('matches Arabic content while the app is in English', () {
      expect(matchesQuery(a, 'حمام'), isTrue);
    });
  });

  group('canSubmitStaged', () {
    test('nothing ticked cannot be submitted', () {
      final a = _a(items: [_item('i1')]);
      expect(canSubmitStaged(a, {}, {}), isFalse);
    });

    test('a ticked place that owes a photo blocks the submit', () {
      final a = _a(items: [_item('i1', requiresPhoto: true)]);
      expect(canSubmitStaged(a, {'i1'}, {}), isFalse);
      expect(missingPhotoCount(a, {'i1'}, {}), 1);
    });

    test('a photo staged this session satisfies it', () {
      final a = _a(items: [_item('i1', requiresPhoto: true)]);
      expect(
        canSubmitStaged(
          a,
          {'i1'},
          {
            'i1': ['/tmp/shot.jpg'],
          },
        ),
        isTrue,
      );
    });

    test('a photo already on the server satisfies it', () {
      final a = _a(
        items: [
          _item('i1', requiresPhoto: true, photoPaths: const ['photos/x.jpg']),
        ],
      );
      expect(canSubmitStaged(a, {'i1'}, {}), isTrue);
    });

    test('an unticked place that requires a photo does not block', () {
      // This is the whole point of partial submit: leave the padel court for
      // later and send the pool round now.
      final a = _a(items: [_item('i1'), _item('i2', requiresPhoto: true)]);
      expect(canSubmitStaged(a, {'i1'}, {}), isTrue);
      expect(missingPhotoCount(a, {'i1'}, {}), 0);
    });

    test('a place already done on the server counts as ticked', () {
      final a = _a(items: [_item('i1', status: 'done')]);
      expect(isItemChecked(a.items.first, {}), isTrue);
      expect(canSubmitStaged(a, {}, {}), isTrue);
    });

    test('a done place still owing a photo blocks the whole round', () {
      final a = _a(items: [_item('i1', status: 'done', requiresPhoto: true)]);
      expect(canSubmitStaged(a, {}, {}), isFalse);
    });
  });

  group('itemPhotos', () {
    test('server photos come before the ones staged this session', () {
      final i = _item('i1', photoPaths: const ['photos/old.jpg']);
      expect(
        itemPhotos(i, {
          'i1': ['/tmp/new.jpg'],
        }),
        ['photos/old.jpg', '/tmp/new.jpg'],
      );
    });
  });
}
