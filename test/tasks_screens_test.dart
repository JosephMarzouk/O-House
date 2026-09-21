import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/fixtures.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/theme.dart';

/// These two screens are dense — an ink header with a search field and a tab
/// row, cards carrying a tag and a progress bar, 68px subtask tiles — and the
/// failure they invite is a RenderFlex overflow at a real phone width, in
/// Arabic, where every string is a different length. A widget test fails on
/// overflow, so pumping both screens in both languages is the cheapest way to
/// keep that honest.
///
/// The submit rule is the other thing worth pinning here rather than only in
/// tasks_logic_test: the gate is pure, but whether the button is actually wired
/// to it is not.
///
/// Colours, spacing and the camera are left to manual verification.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String locale = 'en',
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myAssignmentsProvider.overrideWith((ref) => demoAssignments()),
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
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit & Sign'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('ticking a place that owes a photo blocks the submit', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await tester.tap(find.text('Sun loungers'));
      await tester.pumpAndSettle();

      expect(find.text('4/7 done'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit & Sign'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('1 place still needs a photo'), findsOneWidget);
    });

    testWidgets('a tick made this session can be taken back', (tester) async {
      await _pump(tester, detail('demo-1'));

      await tester.tap(find.text('Towel station'));
      await tester.pumpAndSettle();
      expect(find.text('4/7 done'), findsOneWidget);

      await tester.tap(find.text('Towel station'));
      await tester.pumpAndSettle();
      expect(find.text('3/7 done'), findsOneWidget);
    });

    testWidgets('a place already done on the server cannot be unticked', (
      tester,
    ) async {
      await _pump(tester, detail('demo-1'));

      await tester.tap(find.text('Pool deck'));
      await tester.pumpAndSettle();

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
}
