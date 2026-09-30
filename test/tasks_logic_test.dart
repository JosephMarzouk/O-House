import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/models/assignment_item.dart';
import 'package:o_house/widgets/evidence_video.dart';

/// The two rules on these screens that can be wrong without looking wrong.
///
/// `tabFor` decides which of three tabs an assignment appears under, and a
/// bug there hides work rather than showing an error — a round that lands in
/// no tab at all is simply never done. It is asserted as a total partition
/// for that reason.
///
/// `canSubmitStaged` is the partial-submit gate. It deliberately differs from
/// Assignment.canSubmit (all items done) and from the server's contract, so
/// there is nothing else in the codebase to check it against. Since 0013 it
/// also carries the follow-up rule — a resubmit needs a fresh answer — which
/// fails the same quiet way: a button that is enabled or disabled wrongly.
///
/// `normalizeAnswer` is the wire form of a typed answer, and a digit left in
/// Arabic-Indic form is stored — and quoted back to staff — as typed.
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
  DateTime? endDate,
  DateTime? deadline,
  String status = 'pending',
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
  endDate: endDate,
  windowStart: '07:00:00',
  windowEnd: '11:00:00',
  status: status,
  effectiveStatus: status,
  wasExtended: false,
  extensionNote: null,
  submittedAt: null,
  completedAt: null,
  lateSync: false,
  signatureUrl: null,
  reviewNote: null,
  items: items,
  deadline: deadline,
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

    test('a multi-day task is in Today on each of its days', () {
      // 1–5 Sep, seen on the 3rd: neither History (it started) nor Upcoming.
      final spans = _a(
        scheduledDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5),
      );
      expect(tabFor(spans, now), TaskTab.today);
      expect(spans.isOnDay(now), isTrue);
      expect(spans.isOnDay(DateTime(2026, 9, 5, 23)), isTrue);
      expect(spans.isOnDay(DateTime(2026, 9, 6)), isFalse);
      expect(spans.isOnDay(DateTime(2026, 8, 31)), isFalse);
      // Ended yesterday → History; starts tomorrow → Upcoming.
      expect(
        tabFor(
          _a(scheduledDate: DateTime(2026, 8, 30), endDate: DateTime(2026, 9, 2)),
          now,
        ),
        TaskTab.history,
      );
      expect(
        tabFor(
          _a(scheduledDate: DateTime(2026, 9, 4), endDate: DateTime(2026, 9, 6)),
          now,
        ),
        TaskTab.upcoming,
      );
    });

    test('a clip is told apart from a photo by its extension', () {
      expect(isVideoPath('/data/evidence/abc.mp4'), isTrue);
      expect(isVideoPath('photos/a/i-p.MP4'), isTrue);
      expect(isVideoPath('https://x.supabase.co/sign/photos/a/i-p.mp4?token=t'), isTrue);
      expect(isVideoPath('photos/a/i-p.jpg'), isFalse);
      expect(isVideoPath('signatures/a-s.png'), isFalse);
    });

    test('an overnight window still open after midnight stays in Today', () {
      // 22:00 on the 2nd → 01:00 on the 3rd, seen at 00:30 on the 3rd: by
      // day it is yesterday's, but it can still be filled.
      final night = DateTime(2026, 9, 3, 0, 30);
      final overnight = _a(
        scheduledDate: DateTime(2026, 9, 2),
        deadline: DateTime(2026, 9, 3, 1),
      );
      expect(tabFor(overnight, night), TaskTab.today);
      expect(overnight.isTodayAt(night), isTrue);
      // Once it closes it is History, and a closed one never stays behind.
      expect(tabFor(overnight, DateTime(2026, 9, 3, 1, 5)), TaskTab.history);
      expect(
        tabFor(
          _a(
            scheduledDate: DateTime(2026, 9, 2),
            deadline: DateTime(2026, 9, 3, 1),
            status: 'submitted',
          ),
          night,
        ),
        TaskTab.history,
      );
      // A future deadline does not pull an upcoming round forward.
      expect(
        tabFor(
          _a(scheduledDate: DateTime(2026, 9, 4), deadline: DateTime(2026, 9, 4, 11)),
          night,
        ),
        TaskTab.upcoming,
      );
    });

    test('an assignment with no date is never dropped', () {
      expect(tabFor(_a(), now), TaskTab.today);
    });

    test('a follow_up round is in Today whatever its date', () {
      // Sent days ago but still waiting on this person — by day alone it
      // would be buried in History, where nobody looks for work.
      expect(
        tabFor(
          _a(scheduledDate: DateTime(2026, 8, 20), status: 'follow_up'),
          now,
        ),
        TaskTab.today,
      );
      expect(
        tabFor(
          _a(scheduledDate: DateTime(2026, 9, 5), status: 'follow_up'),
          now,
        ),
        TaskTab.today,
      );
    });
  });

  group('normalizeAnswer', () {
    test('folds Arabic-Indic digits and the Arabic decimal separator', () {
      expect(normalizeAnswer('number', '٢٫٥'), '2.5');
      expect(normalizeAnswer('number', '-٠٫٧٥'), '-0.75');
    });

    test('folds the extended (Persian/Urdu) digit set too', () {
      expect(normalizeAnswer('number', '۱۲۰'), '120');
    });

    test('reads a decimal comma as a point, and trims', () {
      expect(normalizeAnswer('number', ' 3,5 '), '3.5');
      expect(normalizeAnswer('number', '7'), '7');
    });

    test('only trims every other type', () {
      // A comma in free text is just a comma; digits stay as written.
      expect(normalizeAnswer('text', '  3,5 kg ٢ '), '3,5 kg ٢');
      expect(normalizeAnswer('yesno', ' yes '), 'yes');
      expect(normalizeAnswer('pass_fail', 'fail'), 'fail');
    });

    test('whitespace alone is no answer at all', () {
      expect(normalizeAnswer('number', '   '), isEmpty);
      expect(normalizeAnswer('text', '\n '), isEmpty);
    });
  });

  group('answers', () {
    test('any staged answer counts, a "no" included', () {
      // A "no" is an answer, not an empty box — the rule decides if it is
      // the right one.
      expect(isItemChecked(_item('i1'), {'i1': 'no'}), isTrue);
      expect(isItemChecked(_item('i1'), {}), isFalse);
    });

    test('a follow_up item is unanswered until it is answered again', () {
      final flagged = _item('i1', status: 'follow_up');
      expect(isItemChecked(flagged, {}), isFalse);
      expect(isItemChecked(flagged, {'i1': 'yes'}), isTrue);
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
    test('nothing answered cannot be submitted', () {
      final a = _a(items: [_item('i1')]);
      expect(canSubmitStaged(a, {}, {}), isFalse);
    });

    test('an answered place that owes a photo blocks the submit', () {
      final a = _a(items: [_item('i1', requiresPhoto: true)]);
      expect(canSubmitStaged(a, {'i1': 'yes'}, {}), isFalse);
      expect(missingPhotoCount(a, {'i1': 'yes'}, {}), 1);
    });

    test('a photo staged this session satisfies it', () {
      final a = _a(items: [_item('i1', requiresPhoto: true)]);
      expect(
        canSubmitStaged(
          a,
          {'i1': 'yes'},
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
      expect(canSubmitStaged(a, {'i1': 'no'}, {}), isTrue);
    });

    test('an unanswered place that requires a photo does not block', () {
      // This is the whole point of partial submit: leave the padel court for
      // later and send the pool round now.
      final a = _a(items: [_item('i1'), _item('i2', requiresPhoto: true)]);
      expect(canSubmitStaged(a, {'i1': 'yes'}, {}), isTrue);
      expect(missingPhotoCount(a, {'i1': 'yes'}, {}), 0);
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

  // A follow_up round was sent once already, so what the server holds proves
  // nothing new; only an answer made now does.
  group('the follow-up submit gate', () {
    test('work already on the server is not enough to resend', () {
      final a = _a(
        status: 'follow_up',
        items: [
          _item('i1', status: 'done'),
          _item('i2', status: 'follow_up'),
        ],
      );
      // The same round outside follow_up would pass on the done item alone.
      expect(canSubmitStaged(a, {}, {}), isFalse);
    });

    test('fixing one of several flagged answers is enough', () {
      // Partial fixes are allowed; the round stays in follow_up server-side
      // until none are left, rather than the app holding the resend back.
      final a = _a(
        status: 'follow_up',
        items: [
          _item('i1', status: 'follow_up'),
          _item('i2', status: 'follow_up'),
          _item('i3', status: 'follow_up'),
        ],
      );
      expect(canSubmitStaged(a, {'i2': 'yes'}, {}), isTrue);
    });

    test('a flagged place owes its photo even while not re-answered', () {
      // submit_assignment() counts follow_up items as answered work, so a
      // gate that let this through would open onto a MISSING_PHOTO.
      final a = _a(
        status: 'follow_up',
        items: [
          _item('i1', status: 'follow_up', requiresPhoto: true),
          _item('i2'),
        ],
      );
      expect(missingPhotoCount(a, {'i2': 'no'}, {}), 1);
      expect(canSubmitStaged(a, {'i2': 'no'}, {}), isFalse);
      expect(
        canSubmitStaged(
          a,
          {'i2': 'no'},
          {
            'i1': ['/tmp/retake.jpg'],
          },
        ),
        isTrue,
      );
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
