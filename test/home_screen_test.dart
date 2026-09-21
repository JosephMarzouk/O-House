import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/local_db.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/data/sync.dart';
import 'package:o_house/features/home/home_header.dart';
import 'package:o_house/features/home/home_screen.dart';
import 'package:o_house/features/splash_handoff.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/models/profile.dart';
import 'package:o_house/widgets/app_nav_bar.dart';
import 'package:o_house/widgets/ink_handoff_panel.dart';

/// The home screen's one piece of real logic is the Today-and-still-open
/// filter behind the round summary and Next up: it drives a count, a combined
/// window span, and which assignment gets named. All three break silently —
/// a wrong span still renders a plausible-looking line. The status tiles are
/// covered incidentally, since a broken filter would move those too.
///
/// Pumped at the design's 410x864 phone size, as login_screen_test does.

/// start() opens a connectivity stream over a platform channel that does not
/// exist in tests. Nothing here exercises sync, so stub it out.
class _NoopSync extends SyncService {
  _NoopSync() : super(LocalDb.instance);
  @override
  Future<void> start() async {}
}

Assignment _a({
  required String id,
  required String status,
  required DateTime date,
  String? start,
  String? end,
  String title = 'Task',
  String? site,
}) => Assignment(
  id: id,
  assigneeId: 'u1',
  assigneeName: 'Joseph Marzouk',
  titleEn: title,
  titleAr: '',
  siteNameEn: site,
  siteNameAr: null,
  scheduledDate: date,
  windowStart: start,
  windowEnd: end,
  status: status,
  effectiveStatus: status,
  wasExtended: false,
  extensionNote: null,
  submittedAt: null,
  completedAt: null,
  lateSync: false,
  signatureUrl: null,
  reviewNote: null,
);

Future<void> _pumpHome(
  WidgetTester tester,
  List<Assignment> assignments, {
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myAssignmentsProvider.overrideWith((ref) => assignments),
        currentProfileProvider.overrideWith(
          (ref) => const Profile(
            id: 'u1',
            name: 'Joseph Marzouk',
            phone: null,
            role: 'cleaner',
            locale: 'en',
            active: true,
            mustChangePassword: false,
          ),
        ),
        // Both reach sqflite, which has no test binding.
        outboxCountProvider.overrideWith((ref) => 0),
        syncServiceProvider.overrideWith((ref) => _NoopSync()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle(); // past the ink panel's collapse
}

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  // Both are one-shot globals for the whole process — reset before each test
  // so none of them inherits whatever the previous one left behind.
  setUp(() {
    splashHandoffPlayed = false;
    loginHandoffFromHeight = null;
  });

  // Counts are deliberately all distinct so find.text can tell the tiles
  // apart. Terminal statuses and yesterday's row are the two things that
  // must stay out of the span.
  final fixture = <Assignment>[
    _a(
      id: '1',
      status: 'pending',
      date: today,
      start: '07:00:00',
      end: '11:00:00',
      title: 'Morning round',
      site: 'Swimming pool',
    ),
    _a(
      id: '2',
      status: 'pending',
      date: today,
      start: '13:00:00',
      end: '15:00:00',
    ),
    // Yesterday, and wide enough to blow the span open if isToday breaks.
    _a(
      id: '3',
      status: 'pending',
      date: yesterday,
      start: '05:00:00',
      end: '23:00:00',
    ),
    _a(
      id: '4',
      status: 'in_progress',
      date: today,
      start: '08:00:00',
      end: '09:30:00',
    ),
    for (var i = 0; i < 2; i++)
      _a(
        id: 's$i',
        status: 'submitted',
        date: today,
        start: '06:00:00',
        end: '23:30:00',
      ),
    for (var i = 0; i < 4; i++)
      _a(
        id: 'e$i',
        status: 'expired',
        date: today,
        start: '00:30:00',
        end: '23:45:00',
      ),
  ];

  testWidgets('each status tile shows its own count across all assignments', (
    tester,
  ) async {
    await _pumpHome(tester, fixture);

    expect(find.text('To do'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 2 today + 1 yesterday
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the round summary spans only today\'s outstanding work', (
    tester,
  ) async {
    await _pumpHome(tester, fixture);

    // 2 pending today + 1 in progress. The submitted and expired rows are
    // terminal and yesterday's is not today, so none of their much wider
    // windows may reach the span: 07:00 (earliest start) to 15:00 (latest
    // end), NOT 00:30 – 23:45.
    expect(find.text('3 assignments · 07:00 – 15:00'), findsOneWidget);
  });

  testWidgets('Next up names the earliest outstanding task today', (
    tester,
  ) async {
    await _pumpHome(tester, fixture);

    expect(find.text('Next up'), findsOneWidget);
    // Same TaskCard the Tasks screen uses, so title/site/window/progress are
    // separate texts rather than one joined summary line.
    expect(find.text('Morning round'), findsOneWidget);
    expect(find.text('Swimming pool'), findsOneWidget);
    expect(find.text('07:00 – 11:00'), findsOneWidget);
    expect(find.text('0/0 done'), findsOneWidget);
  });

  testWidgets('a clear day drops the summary and shows the empty state', (
    tester,
  ) async {
    await _pumpHome(tester, [
      _a(
        id: 'x',
        status: 'submitted',
        date: today,
        start: '07:00:00',
        end: '11:00:00',
      ),
      _a(id: 'y', status: 'pending', date: yesterday),
    ]);

    // The section keeps its place; only its contents change.
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Nothing upcoming right now'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    // No outstanding work today means no span to report.
    expect(find.textContaining('assignments ·'), findsNothing);
    // The rest of the screen still renders.
    expect(find.text('My Tasks'), findsOneWidget);
  });

  testWidgets('Next up sits at the bottom, below the round summary', (
    tester,
  ) async {
    await _pumpHome(tester, fixture);

    final summary = tester.getRect(find.textContaining('assignments ·'));
    final nextUp = tester.getRect(find.text('Next up'));
    final viewport = tester.getRect(find.byType(CustomScrollView));

    expect(nextUp.top, greaterThan(summary.bottom));
    // Pushed down by the Spacer rather than trailing straight after the
    // summary — it should be in the bottom half of the viewport. (The full
    // TaskCard is taller than the old summary-line widget, so it starts
    // higher than a bare-bones "bottom third" would allow — the Spacer still
    // did its job as long as there's real empty space above it.)
    expect(nextUp.top, greaterThan(viewport.top + viewport.height * 0.5));

    // ...but it must stop above the floating nav bar, not slide under it.
    // The clearance has to live inside the filled column; as SliverPadding
    // it only adds scrollable space and the Spacer overshoots into the bar.
    // The progress label is TaskCard's last line, so its bottom is the
    // card's own bottom edge.
    final last = tester.getRect(find.text('0/0 done'));
    expect(last.bottom, lessThan(viewport.bottom - kNavBarContentHeight));
  });

  // The ink header is the one thing that shows a seam if it is wrong: it has
  // to open on exactly the pixels the previous screen ended on, whether that
  // was the splash (full screen) or Login (its own, much shorter header).
  group('ink hand-off', () {
    final ink = find.descendant(
      of: find.byType(InkHandoffPanel),
      matching: find.byType(AnimatedContainer),
    );

    testWidgets('from the splash, the ink opens full screen', (tester) async {
      await _pumpHome(tester, fixture, settle: false);

      expect(tester.getRect(ink).height, 864);
      await tester.pumpAndSettle();
      expect(tester.getRect(ink).height, kHomeHeaderContentHeight);
    });

    testWidgets('from Login, it opens on Login\'s header instead', (
      tester,
    ) async {
      splashHandoffPlayed = true; // the splash hand-off already played
      loginHandoffFromHeight = 256; // Login's collapsed header height

      await _pumpHome(tester, fixture, settle: false);

      // Continues Login's motion rather than re-expanding to full screen.
      expect(tester.getRect(ink).height, 256);
      // Consumed, so a later visit to Home does not replay it.
      expect(loginHandoffFromHeight, isNull);

      await tester.pumpAndSettle();
      expect(tester.getRect(ink).height, kHomeHeaderContentHeight);
    });

    testWidgets('a later visit does not animate at all', (tester) async {
      splashHandoffPlayed = true; // and no login hand-off pending

      await _pumpHome(tester, fixture, settle: false);

      expect(tester.getRect(ink).height, kHomeHeaderContentHeight);
    });
  });

  testWidgets('pulling down re-runs the assignments fetch', (tester) async {
    var builds = 0;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(410, 864);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myAssignmentsProvider.overrideWith((ref) {
            builds++;
            return fixture;
          }),
          currentProfileProvider.overrideWith((ref) => null),
          outboxCountProvider.overrideWith((ref) => 0),
          syncServiceProvider.overrideWith((ref) => _NoopSync()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(builds, 1);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    expect(builds, 2);
  });
}
