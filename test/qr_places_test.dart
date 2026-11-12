import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/assignments_repo.dart';
import 'package:o_house/data/local_db.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/group_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/features/assignments/qr_scan.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/push/push_service.dart';
import 'package:o_house/theme.dart';
import 'package:o_house/widgets/subtask_tile.dart';

/// QR-locked places on multi-place tasks: the hash match, the lock (a queued
/// scan included), the grouping on Tasks, the push route, and the two new
/// faces (a task's places, a locked checklist) at phone width in EN and AR.
/// The camera itself is left to the real phone. The outbox's `scan` op is in
/// outbox_test.dart, the kept signature in submit_sync_test.dart.

/// The pool sticker's code (`clubops:ohouse:c0de`).
const _pool = 'c0de';

/// A place's checklist as the API sends it (the view's snake_case).
Assignment _place(
  String id, {
  String title = 'Swimming pool',
  String titleAr = 'المسبح',
  String? group = 'g1',
  int size = 3,
  bool qr = false,
  String? hash,
  bool unlocked = false,
  String status = 'pending',
  String? start,
  int? position,
  DateTime? date,
  DateTime? opensAt,
}) => Assignment.fromJson({
  'opens_at': opensAt?.toUtc().toIso8601String(),
  'id': id,
  'inspector_id': 'u1',
  'title_en': title,
  'title_ar': titleAr,
  'scheduled_date': (date ?? DateTime.now()).toIso8601String(),
  'window_start': start,
  'window_end': start == null ? null : '23:59:00',
  'status': status,
  'effective_status': status,
  'group_id': group,
  'group_title_en': group == null ? null : 'Morning zone',
  'group_title_ar': group == null ? null : 'منطقة الصباح',
  'group_size': group == null ? 1 : size,
  'group_position': position,
  'qr_required': qr,
  'qr_hash': hash,
  'unlocked': unlocked,
  'items': [
    {
      'id': '$id-i1',
      'assignment_id': id,
      'text_en': 'Floor dry',
      'text_ar': 'الأرضية جافة',
      'status': 'pending',
    },
  ],
});

/// Squash (open), pool (locked), HR room (sent): one task, walked in that
/// order by window, listed here out of order on purpose.
List<Assignment> _task() => [
  _place(
    'hr',
    title: 'HR room',
    titleAr: 'غرفة الموارد البشرية',
    start: '09:00:00',
    status: 'submitted',
  ),
  _place('pool', qr: true, hash: qrHashOf(_pool), start: '08:00:00'),
  _place(
    'squash',
    title: 'Squash court',
    titleAr: 'ملعب الإسكواش',
    qr: true,
    hash: 'aa',
    unlocked: true,
    start: '07:00:00',
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required List<Assignment> assignments,
  String locale = 'en',
  DateTime? now,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userIdProvider.overrideWithValue(null),
        myAssignmentsProvider.overrideWith((ref) => assignments),
        outboxCountProvider.overrideWith((ref) => 0),
        if (now != null) serverClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the QR payload and its hash', () {
    test("sha256 of the code, lowercase hex, as the view's digest", () {
      expect(
        qrHashOf('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    final places = [
      _place('pool', qr: true, hash: qrHashOf(_pool)),
      _place('gym', qr: true, hash: qrHashOf('9999')),
    ];
    QrMatch match(String raw, [List<Assignment>? candidates, DateTime? now]) =>
        matchQr(
          raw,
          clubSlug: 'ohouse',
          candidates: candidates ?? places,
          now: now ?? DateTime.now(),
        );

    test("this club's sticker opens its place, and carries the code", () {
      final r = match('clubops:ohouse:$_pool');
      expect(r.verdict, QrVerdict.match);
      expect(r.place!.id, 'pool');
      expect(r.code, _pool);
      // Whitespace a scanner adds around the text is not part of it.
      expect(match(' clubops:ohouse:$_pool\n').place!.id, 'pool');
    });

    test("another club's sticker says so, even with a matching code", () {
      expect(match('clubops:ryze:$_pool').verdict, QrVerdict.wrongClub);
    });

    test("any other QR is not part of this task", () {
      for (final raw in [
        'clubops:ohouse:unknown',
        'https://example.com',
        'clubops:ohouse',
        'clubops::$_pool',
        'clubops:ohouse:',
        'CLUBOPS:ohouse:$_pool',
        '',
      ]) {
        expect(match(raw).verdict, QrVerdict.notInTask, reason: raw);
      }
    });

    test('a place that can no longer be filled, or has no lock, never matches', () {
      expect(
        match('clubops:ohouse:$_pool', [
          _place('pool', qr: true, hash: qrHashOf(_pool), status: 'submitted'),
          _place('pool2', hash: qrHashOf(_pool)), // qr_required off
        ]).verdict,
        QrVerdict.notInTask,
      );
    });

    test('one sticker on two checklists: the locked one, then walk order', () {
      final h = qrHashOf(_pool);
      final r = match('clubops:ohouse:$_pool', [
        _place('evening', qr: true, hash: h, start: '18:00:00'),
        _place('morning', qr: true, hash: h, start: '07:00:00', unlocked: true),
        _place('noon', qr: true, hash: h, start: '12:00:00'),
      ]);
      expect(r.place!.id, 'noon');
      // All open already: scanning again just opens the first.
      final again = match('clubops:ohouse:$_pool', [
        _place('evening', qr: true, hash: h, start: '18:00:00', unlocked: true),
        _place('morning', qr: true, hash: h, start: '07:00:00', unlocked: true),
      ]);
      expect(again.verdict, QrVerdict.match);
      expect(again.place!.id, 'morning');
    });

    // The same place twice in one round, each in its own period (12 Nov).
    final h = qrHashOf(_pool);
    final today = DateTime(2026, 11, 13);
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 11, 13, hour, minute);

    test('two periods of one place: the scan opens the one whose time has come', () {
      final slots = [
        _place('noon', qr: true, hash: h, start: '12:00:00', position: 1, date: today, opensAt: at(12)),
        _place('morning', qr: true, hash: h, start: '08:00:00', position: 2, date: today, opensAt: at(8)),
      ];
      // The admin listed noon first; at 08:30 it is the morning one.
      final r = match('clubops:ohouse:$_pool', slots, at(8, 30));
      expect(r.verdict, QrVerdict.match);
      expect(r.place!.id, 'morning');
      expect(match('clubops:ohouse:$_pool', slots, at(12, 30)).place!.id, 'noon');
    });

    test('before its time a right sticker opens nothing, and says when', () {
      final slots = [
        _place('noon', qr: true, hash: h, start: '12:00:00', date: today, opensAt: at(12)),
        _place('ten', qr: true, hash: h, start: '10:00:00', date: today, opensAt: at(10)),
      ];
      final r = match('clubops:ohouse:$_pool', slots, at(9));
      expect(r.verdict, QrVerdict.notOpenYet);
      expect(r.place!.id, 'ten'); // the earliest
      expect(r.code, isNull); // nothing to queue
    });

    test('it opens 5 minutes early, not 6', () {
      final ten = [
        _place('ten', qr: true, hash: h, start: '10:00:00', date: today, opensAt: at(10)),
      ];
      expect(match('clubops:ohouse:$_pool', ten, at(9, 54)).verdict, QrVerdict.notOpenYet);
      expect(match('clubops:ohouse:$_pool', ten, at(9, 55)).verdict, QrVerdict.match);
    });

    test("scanning from a task reaches only its places; else today's", () {
      final all = [
        _place('a', group: 'g1'),
        _place('b', group: 'g2'),
        _place('c', group: null),
        _place('old', group: null, date: DateTime(2020)),
      ];
      expect(scanCandidates(all, 'g1').map((a) => a.id), ['a']);
      expect(scanCandidates(all, null).map((a) => a.id), ['a', 'b', 'c']);
    });
  });

  group('the lock', () {
    test('missing fields are today\'s checklist: no lock, no group', () {
      final a = Assignment.fromJson({'id': 'x', 'status': 'pending'});
      expect(a.qrRequired, isFalse);
      expect(a.groupId, isNull);
      expect(a.groupSize, 1);
      expect(a.unlocked, isFalse);
      expect(a.isLocked, isFalse);
      expect(a.isGrouped, isFalse);
    });

    test('the new fields survive the cache round trip', () {
      final a = _place('pool', qr: true, hash: 'h', unlocked: true);
      final b = Assignment.fromJson(a.toCacheJson());
      expect(
        [b.qrRequired, b.groupId, b.groupTitleEn, b.groupTitleAr, b.groupSize, b.qrHash, b.unlocked],
        [true, 'g1', 'Morning zone', 'منطقة الصباح', 3, 'h', true],
      );
    });

    test('locked until scanned; a closed checklist is only read, never locked', () {
      expect(_place('p', qr: true).isLocked, isTrue);
      expect(_place('p', qr: true, unlocked: true).isLocked, isFalse);
      expect(_place('p').isLocked, isFalse);
      for (final s in ['submitted', 'approved', 'expired']) {
        expect(_place('p', qr: true, status: s).isLocked, isFalse, reason: s);
      }
      // Sent back: still to be filled, so still behind its QR.
      expect(_place('p', qr: true, status: 'rejected').isLocked, isTrue);
    });

    test('a scan queued on this phone opens the place at once, offline', () {
      final scan = OutboxOp(
        seq: 1,
        id: 's1',
        userId: 'u1',
        assignmentId: 'pool',
        op: 'scan',
        payload: {'code': _pool, 'scannedAt': 'x', 'scanId': 'y'},
        attempts: 0,
        parkedCode: null,
        parkedMessage: null,
      );
      final a = applyLocal(
        _place('pool', qr: true, hash: 'h'),
        [scan],
        evidencePath: '/ev',
        serverNow: DateTime.now(),
      );
      expect(a.unlocked, isTrue);
      expect(a.isLocked, isFalse);
      // A scan is not an answer: the place is still pending.
      expect(a.effectiveStatus, 'pending');
      // Another checklist's scan opens nothing here.
      expect(
        applyLocal(
          _place('gym', qr: true, hash: 'h'),
          [scan],
          evidencePath: '/ev',
          serverNow: DateTime.now(),
        ).isLocked,
        isTrue,
      );
    });
  });

  group('grouping on Tasks', () {
    test('walk order: by window, none last, ties as they came', () {
      final order = walkOrder([
        _place('none'),
        _place('b', start: '09:00:00'),
        _place('a1', start: '07:00:00'),
        _place('a2', start: '07:00:00'),
      ]);
      expect(order.map((a) => a.id), ['a1', 'a2', 'b', 'none']);
    });

    test("walk order: the admin's position first, even with one shared window", () {
      // A one-off task: every place on the task's window, all created in
      // the same instant, arriving in any order. Only the position knows.
      final order = walkOrder([
        _place('hr', start: '15:00:00', position: 3),
        _place('old-api', start: '07:00:00'),
        _place('squash', start: '15:00:00', position: 1),
        _place('pool', start: '15:00:00', position: 2),
      ]);
      expect(order.map((a) => a.id), ['squash', 'pool', 'hr', 'old-api']);
      // And it survives the phone's cache.
      final cached = Assignment.fromJson(order.first.toCacheJson());
      expect(cached.groupPosition, 1);
    });

    test("a task's places collapse where its first place stands", () {
      final entries = taskEntries([
        _place('single', group: null),
        ..._task(),
        _place('round-of-one', group: 'g9', size: 1),
      ], '');
      expect(entries.map((e) => e.groupId), [null, 'g1', null]);
      expect(entries[1].places.map((a) => a.id), ['hr', 'pool', 'squash']);
      // A group of one is just a checklist.
      expect(entries[2].places.single.id, 'round-of-one');
    });

    test('with an API older than QR places, every card is as before', () {
      final old = [
        for (final id in ['a', 'b']) Assignment.fromJson({'id': id, 'title_en': id}),
      ];
      expect(taskEntries(old, '').map((e) => e.places.single.id), ['a', 'b']);
    });

    test('search finds a task by a place or its own name, and keeps it whole', () {
      expect(taskEntries(_task(), 'squash').single.places, hasLength(3));
      expect(taskEntries(_task(), 'morning').single.groupId, 'g1');
      expect(taskEntries(_task(), 'صباح').single.groupId, 'g1');
      expect(taskEntries(_task(), 'lobby'), isEmpty);
    });
  });

  group('push', () {
    test("a task's push opens its places", () {
      expect(routeFor({'open': 'group', 'groupId': 'g1'}), '/groups/g1');
      expect(routeFor({'open': 'group'}), isNull);
      expect(routeFor({'open': 'group', 'groupId': ''}), isNull);
      // The old cases are untouched.
      expect(routeFor({'open': 'task', 'assignmentId': 'a1'}), '/tasks/a1');
    });
  });

  group("a task's places screen", () {
    for (final locale in ['en', 'ar']) {
      testWidgets('lists the places in walk order with their state ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const GroupScreen(groupId: 'g1'),
          assignments: [..._task(), _place('other', group: 'g2')],
          locale: locale,
        );
        final en = locale == 'en';
        expect(find.text(en ? 'Morning zone' : 'منطقة الصباح'), findsOneWidget);
        final squash = tester.getTopLeft(find.text(en ? 'Squash court' : 'ملعب الإسكواش'));
        final pool = tester.getTopLeft(find.text(en ? 'Swimming pool' : 'المسبح'));
        final hr = tester.getTopLeft(
          find.text(en ? 'HR room' : 'غرفة الموارد البشرية'),
        );
        expect(squash.dy < pool.dy && pool.dy < hr.dy, isTrue);
        // Only the pool waits for its QR, so one lock and the Scan button.
        expect(find.text(en ? 'Locked' : 'مقفل'), findsOneWidget);
        expect(find.text(en ? 'Scan QR' : 'مسح رمز QR'), findsOneWidget);
        // The other task's pool is not here, only this task's.
        expect(find.text(en ? 'Swimming pool' : 'المسبح'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no Scan button once every place is open', (tester) async {
      await _pump(
        tester,
        const GroupScreen(groupId: 'g1'),
        assignments: [_place('a', qr: true, unlocked: true), _place('b')],
      );
      expect(find.text('Scan QR'), findsNothing);
    });

    testWidgets('a task no longer on this phone says so', (tester) async {
      await _pump(tester, const GroupScreen(groupId: 'gone'), assignments: _task());
      expect(find.text('Scan QR'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget); // Back to tasks
    });

    testWidgets('the Tasks list shows the task as one card (ar)', (tester) async {
      await _pump(
        tester,
        const TasksListScreen(),
        assignments: [
          ..._task(),
          _place('single', group: null, title: 'Lobby', titleAr: 'الردهة'),
        ],
        locale: 'ar',
      );
      expect(find.text('منطقة الصباح'), findsOneWidget);
      expect(find.text('المسبح'), findsNothing);
      expect(find.text('الأماكن المنجزة: 1 من 3'), findsOneWidget);
      expect(find.text('المقفلة: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a locked checklist', () {
    for (final locale in ['en', 'ar']) {
      testWidgets('reads, but answers nothing until scanned ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          const TaskDetailScreen(assignmentId: 'pool'),
          assignments: _task(),
          locale: locale,
        );
        final en = locale == 'en';
        expect(
          find.text(
            en
                ? 'Scan the Swimming pool QR to start'
                : 'امسح رمز QR في المسبح للبدء',
          ),
          findsOneWidget,
        );
        expect(find.text(en ? 'Scan QR' : 'مسح رمز QR'), findsOneWidget);
        expect(find.text(en ? 'Floor dry' : 'الأرضية جافة'), findsOneWidget);
        expect(tester.widget<SubtaskTile>(find.byType(SubtaskTile)).locked, isTrue);
        expect(find.text(en ? 'Submit & Sign' : 'إرسال وتوقيع'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('once scanned it is an ordinary checklist', (tester) async {
      await _pump(
        tester,
        const TaskDetailScreen(assignmentId: 'squash'),
        assignments: _task(),
      );
      expect(find.text('Scan QR'), findsNothing);
      expect(tester.widget<SubtaskTile>(find.byType(SubtaskTile)).locked, isFalse);
      expect(find.text('Submit & Sign'), findsOneWidget);
    });
  });

  group('before its time', () {
    final day = DateTime(2026, 11, 13);
    Assignment ten({bool qr = true, bool unlocked = false, String status = 'pending'}) => _place(
      'ten',
      qr: qr,
      hash: qrHashOf(_pool),
      unlocked: unlocked,
      status: status,
      start: '10:00:00',
      date: day,
      opensAt: DateTime(2026, 11, 13, 10),
    );

    test('opens 5 minutes before the window, on the club clock', () {
      final a = ten();
      expect(a.openClock, '09:55');
      expect(a.isNotOpenAt(DateTime(2026, 11, 13, 9, 54)), isTrue);
      expect(a.isNotOpenAt(DateTime(2026, 11, 13, 9, 55)), isFalse);
      // A window just after midnight opens the evening before.
      expect(_place('x', start: '00:02:00').openClock, '23:57');
    });

    test('only work still to start waits', () {
      final early = DateTime(2026, 11, 13, 8);
      expect(ten(status: 'follow_up').isNotOpenAt(early), isFalse);
      expect(ten(status: 'submitted').isNotOpenAt(early), isFalse);
      expect(ten(status: 'in_progress').isNotOpenAt(early), isTrue);
      // No opens_at (an older API, or no window): no gate.
      expect(_place('old', start: '10:00:00', date: day).isNotOpenAt(early), isFalse);
    });

    for (final locale in ['en', 'ar']) {
      testWidgets('the checklist shows only when it opens ($locale)', (tester) async {
        await _pump(
          tester,
          const TaskDetailScreen(assignmentId: 'ten'),
          // Even a place already scanned stays shut before its time.
          assignments: [ten(unlocked: true)],
          locale: locale,
          now: DateTime(2026, 11, 13, 9),
        );
        final en = locale == 'en';
        expect(find.text(en ? 'Opens at 09:55' : 'يفتح الساعة 09:55'), findsOneWidget);
        expect(find.byType(SubtaskTile), findsNothing);
        expect(find.text(en ? 'Submit & Sign' : 'إرسال وتوقيع'), findsNothing);
        expect(find.text(en ? 'Scan QR' : 'مسح رمز QR'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a later day names the day', (tester) async {
      await _pump(
        tester,
        const TaskDetailScreen(assignmentId: 'ten'),
        assignments: [ten()],
        now: DateTime(2026, 11, 12, 18),
      );
      expect(find.text('Opens Fri 13 Nov at 09:55'), findsOneWidget);
    });

    testWidgets('at its time it is the checklist again', (tester) async {
      await _pump(
        tester,
        const TaskDetailScreen(assignmentId: 'ten'),
        assignments: [ten(qr: false)],
        now: DateTime(2026, 11, 13, 9, 56),
      );
      expect(find.byType(SubtaskTile), findsOneWidget);
      expect(find.text('Submit & Sign'), findsOneWidget);
    });
  });
}
