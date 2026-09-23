import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:o_house/data/fixtures.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/features/assignments/success_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/assignment.dart';
import 'package:o_house/models/assignment_item.dart';
import 'package:o_house/theme.dart';
import 'package:o_house/widgets/subtask_tile.dart';

/// These two screens are dense — an ink header with a search field and a tab
/// row, cards carrying a tag and a progress bar, subtask tiles that now carry
/// an answer control each — and the failure they invite is a RenderFlex
/// overflow at a real phone width, in Arabic, where every string is a
/// different length. A widget test fails on overflow, so pumping both screens
/// in both languages is the cheapest way to keep that honest.
///
/// The submit rule is the other thing worth pinning here rather than only in
/// tasks_logic_test: the gate is pure, but whether the button is actually wired
/// to it — and to the answers the controls stage — is not.
///
/// Colours, spacing and the camera are left to manual verification.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String locale = 'en',
  List<Assignment>? assignments,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userIdProvider.overrideWithValue(null), // no Supabase in tests
        myAssignmentsProvider.overrideWith(
          (ref) => assignments ?? demoAssignments(),
        ),
        // Reaches sqflite, which has no test binding.
        outboxCountProvider.overrideWith((ref) => 0),
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

/// The tile that holds [place].
Finder _tile(String place) =>
    find.ancestor(of: find.text(place), matching: find.byType(SubtaskTile));

/// Taps [label] — 'Yes', 'No', 'Pass', 'Fail' — on [place]'s tile. The tile
/// body itself no longer answers anything.
Future<void> _answer(WidgetTester tester, String place, String label) async {
  final button = find.descendant(of: _tile(place), matching: find.text(label));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

FilledButton _submit(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Submit & Sign'),
);

/// A round sent two days ago that came back with two answers flagged. Built
/// here rather than in fixtures.dart, whose demo rounds other tests pin by
/// text and count.
Assignment _followUpRound() {
  AssignmentItem item(
    String id,
    String en,
    String ar, {
    String type = 'yesno',
    String status = 'pending',
    String? answer,
    Map<String, dynamic>? correct,
  }) => AssignmentItem(
    id: id,
    assignmentId: 'f1',
    textEn: en,
    textAr: ar,
    type: type,
    critical: false,
    requiresPhoto: false,
    sortOrder: 0,
    status: status,
    doneAt: null,
    note: null,
    rejectNote: null,
    photoPaths: const [],
    answer: answer,
    correct: correct,
    flaggedAnswer: status == 'follow_up' ? answer : null,
  );

  final sent = DateTime.now().subtract(const Duration(days: 2));
  return Assignment(
    id: 'f1',
    assigneeId: 'u1',
    assigneeName: 'Joseph Marzouk',
    titleEn: 'Gym check',
    titleAr: 'فحص الصالة',
    siteNameEn: 'Outdoor GYM',
    siteNameAr: 'الصالة الخارجية',
    roundTitleEn: 'Zone 1 Morning',
    roundTitleAr: 'المنطقة 1 صباحًا',
    scheduledDate: sent,
    windowStart: '07:00:00',
    windowEnd: '07:30:00',
    status: 'follow_up',
    effectiveStatus: 'follow_up',
    wasExtended: false,
    extensionNote: null,
    submittedAt: sent,
    completedAt: sent,
    lateSync: false,
    signatureUrl: null,
    reviewNote: null,
    items: [
      item(
        'f1-a',
        'Floor dry',
        'الأرضية جافة',
        status: 'follow_up',
        answer: 'no',
        correct: const {'eq': 'yes'},
      ),
      item(
        'f1-b',
        'Chlorine level',
        'مستوى الكلور',
        type: 'number',
        status: 'follow_up',
        answer: '5',
        correct: const {'min': 1, 'max': 3},
      ),
      item(
        'f1-c',
        'Mirrors',
        'المرايا',
        type: 'pass_fail',
        status: 'done',
        answer: 'pass',
      ),
      item('f1-d', 'Notes for the supervisor', 'ملاحظات للمشرف', type: 'text'),
    ],
  );
}

void main() {
  group('TasksListScreen', () {
    testWidgets(
      'Today shows every round scheduled today, whatever its status',
      (tester) async {
        await _pump(tester, const TasksListScreen());

        expect(find.text('Morning round'), findsOneWidget);
        expect(find.text('Court turnover'), findsOneWidget);
        // Closed rounds belong in Today too — the tab is a day, not a filter.
        expect(find.text('Evening close'), findsOneWidget);
        expect(find.text('Submitted'), findsOneWidget);
        expect(find.text('Expired'), findsOneWidget);
        // Tomorrow's round is not in this tab.
        expect(find.text('Lobby deep clean'), findsNothing);
      },
    );

    testWidgets('the progress bar reports the real done count', (tester) async {
      await _pump(tester, const TasksListScreen());
      expect(find.text('3/7 done'), findsOneWidget);
      expect(find.text('0/5 done'), findsOneWidget);
    });

    testWidgets('tapping Upcoming swaps the list', (tester) async {
      await _pump(tester, const TasksListScreen());

      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(find.text('Lobby deep clean'), findsOneWidget);
      expect(find.text('Morning round'), findsNothing);
    });

    testWidgets('search matches the site name, not only the title', (
      tester,
    ) async {
      await _pump(tester, const TasksListScreen());

      await tester.enterText(find.byType(TextField), 'padel');
      await tester.pumpAndSettle();

      // "Padel court" is the site of Court turnover; its title says nothing
      // about padel.
      expect(find.text('Court turnover'), findsOneWidget);
      expect(find.text('Morning round'), findsNothing);
    });

    testWidgets('a tab with nothing in it shows the empty state', (
      tester,
    ) async {
      await _pump(tester, const TasksListScreen());

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No tasks here yet.'), findsOneWidget);
    });

    testWidgets('lays out in Arabic without overflowing', (tester) async {
      await _pump(tester, const TasksListScreen(), locale: 'ar');

      expect(find.text('الجولة الصباحية'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('الجولة الصباحية'))),
        TextDirection.rtl,
      );
    });

    testWidgets('an old follow_up round is in Today, under its round', (
      tester,
    ) async {
      await _pump(
        tester,
        const TasksListScreen(),
        assignments: [_followUpRound()],
      );

      // Scheduled two days ago — by day alone it would be in History.
      expect(find.text('Gym check'), findsOneWidget);
      expect(find.text('ZONE 1 MORNING'), findsOneWidget);
      expect(find.text('Follow-up'), findsOneWidget);
    });

    testWidgets('the follow-up card lays out in Arabic too', (tester) async {
      // The longest chip label in either language, beside a title.
      await _pump(
        tester,
        const TasksListScreen(),
        assignments: [_followUpRound()],
        locale: 'ar',
      );

      expect(find.text('بحاجة إلى متابعة'), findsOneWidget);
      expect(find.text('المنطقة 1 صباحًا'), findsOneWidget);
    });
  });

  group('TaskDetailScreen', () {
    Widget detail(String id) => TaskDetailScreen(assignmentId: id);

    testWidgets('the header counts progress and the body lists the places', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('3/7 done'), findsOneWidget);
      expect(find.text('Pool deck'), findsOneWidget);
      expect(find.text('Sun loungers'), findsOneWidget);
    });

    testWidgets('a partly finished round can already be submitted', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      // Three places done, none of them owing a photo — under the partial rule
      // that is enough to send.
      expect(_submit(tester).onPressed, isNotNull);
    });

    testWidgets('answering a place that owes a photo blocks the submit', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await _answer(tester, 'Sun loungers', 'Yes');

      expect(find.text('4/7 done'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
      expect(find.text('1 place still needs a photo'), findsOneWidget);
    });

    testWidgets('an answer made this session can be taken back', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await _answer(tester, 'Towel station', 'No');
      expect(find.text('4/7 done'), findsOneWidget);

      // Tapping the picked answer again clears it.
      await _answer(tester, 'Towel station', 'No');
      expect(find.text('3/7 done'), findsOneWidget);
    });

    testWidgets('tapping the place itself no longer answers it', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await tester.tap(find.text('Towel station'));
      await tester.pumpAndSettle();

      // A tap on the name cannot say yes or no, so it says nothing.
      expect(find.text('3/7 done'), findsOneWidget);
    });

    testWidgets('a place already done on the server cannot be re-answered', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await _answer(tester, 'Pool deck', 'No');

      expect(find.text('3/7 done'), findsOneWidget);
    });

    testWidgets('a submitted round offers no submit bar at all', (
      tester,
    ) async {
      await _pump(tester, detail('demo-4'));

      expect(find.text('4/4 done'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Submit & Sign'), findsNothing);
    });

    testWidgets('an expired round shows the locked message instead', (
      tester,
    ) async {
      await _pump(tester, detail('demo-2'));

      expect(
        find.text('Window closed — ask your supervisor to extend.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Submit & Sign'), findsNothing);
    });

    testWidgets('lays out in Arabic without overflowing', (tester) async {
      await _pump(tester, detail('demo-1'), locale: 'ar');

      expect(find.text('حافة المسبح'), findsOneWidget);
      expect(find.text('التقدم'), findsOneWidget);
    });
  });

  group('a follow_up round', () {
    Widget detail() => const TaskDetailScreen(assignmentId: 'f1');

    testWidgets('a flagged item says what was answered and what was expected', (
      tester,
    ) async {
      await _pump(tester, detail(), assignments: [_followUpRound()]);

      expect(
        find.text('Needs follow-up · you answered No · expected Yes'),
        findsOneWidget,
      );
      expect(
        find.text('Needs follow-up · you answered 5 · expected 1–3'),
        findsOneWidget,
      );
      // Only the two flagged items give the expected answer away.
      expect(find.textContaining('expected'), findsNWidgets(2));
      // Flagged answers are not answered until they are answered again.
      expect(find.text('1/4 done'), findsOneWidget);
    });

    testWidgets('resending takes a fresh answer, and one fix is enough', (
      tester,
    ) async {
      await _pump(tester, detail(), assignments: [_followUpRound()]);

      // Mirrors is done on the server, but that was already sent.
      expect(_submit(tester).onPressed, isNull);

      await _answer(tester, 'Floor dry', 'Yes');

      expect(find.text('2/4 done'), findsOneWidget);
      // The chlorine reading is still flagged, and that does not hold it back.
      expect(_submit(tester).onPressed, isNotNull);
    });

    testWidgets('a number typed in Arabic digits is an answer', (tester) async {
      await _pump(tester, detail(), assignments: [_followUpRound()]);
      final field = find.descendant(
        of: _tile('Chlorine level'),
        matching: find.byType(TextField),
      );

      await tester.enterText(field, '٢٫٥');
      await tester.pumpAndSettle();
      expect(find.text('2/4 done'), findsOneWidget);
      expect(_submit(tester).onPressed, isNotNull);

      // Emptying the field takes the answer back.
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(find.text('1/4 done'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
    });

    testWidgets('a done answer shows as sent and stays put', (tester) async {
      await _pump(tester, detail(), assignments: [_followUpRound()]);

      await _answer(tester, 'Mirrors', 'Fail');

      expect(find.text('1/4 done'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
    });

    testWidgets('lays out in Arabic without overflowing', (tester) async {
      await _pump(
        tester,
        detail(),
        assignments: [_followUpRound()],
        locale: 'ar',
      );

      expect(find.text('نعم'), findsOneWidget);
      expect(find.text('ناجح'), findsOneWidget);
      expect(
        find.text('بحاجة إلى متابعة · إجابتك: لا · المتوقع: نعم'),
        findsOneWidget,
      );
      expect(
        find.text('بحاجة إلى متابعة · إجابتك: 5 · المتوقع: من 1 إلى 3'),
        findsOneWidget,
      );
      // The number field stays left-to-right under RTL.
      final number = find.descendant(
        of: _tile('مستوى الكلور'),
        matching: find.byType(EditableText),
      );
      expect(Directionality.of(tester.element(number)), TextDirection.ltr);
    });
  });

  group('SuccessScreen, follow-up face', () {
    testWidgets('says what did not match instead of "for review"', (
      tester,
    ) async {
      await _pump(
        tester,
        const SuccessScreen(assignmentId: 'f1'),
        assignments: [_followUpRound()],
      );

      expect(find.text('Sent — needs follow-up'), findsOneWidget);
      expect(find.text("2 answers didn't match"), findsOneWidget);
      expect(find.text('Review flagged answers'), findsOneWidget);
      expect(find.text('Back to my tasks'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      // Nothing here is waiting on a supervisor yet.
      expect(find.text('Submitted for review'), findsNothing);
      expect(find.text('View submission'), findsNothing);
    });

    testWidgets('lays out in Arabic without overflowing', (tester) async {
      await _pump(
        tester,
        const SuccessScreen(assignmentId: 'f1'),
        assignments: [_followUpRound()],
        locale: 'ar',
      );

      expect(find.text('تم الإرسال — بحاجة إلى متابعة'), findsOneWidget);
      expect(find.text('إجابتان غير مطابقتين'), findsOneWidget);
    });

    testWidgets('Review flagged answers goes back into the round', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(410, 864);
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/success',
        routes: [
          GoRoute(
            path: '/success',
            builder: (_, _) => const SuccessScreen(assignmentId: 'f1'),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, s) => Text('ROUND ${s.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userIdProvider.overrideWithValue(null), // no Supabase in tests
            myAssignmentsProvider.overrideWith((ref) => [_followUpRound()]),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review flagged answers'));
      await tester.pumpAndSettle();

      expect(find.text('ROUND f1'), findsOneWidget);
    });
  });
}
