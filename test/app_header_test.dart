import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:o_house/data/fixtures.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/history_detail_screen.dart';
import 'package:o_house/features/assignments/list_screen.dart';
import 'package:o_house/features/assignments/signature_screen.dart';
import 'package:o_house/features/assignments/success_screen.dart';
import 'package:o_house/features/home/home_header.dart';
import 'package:o_house/features/profile/profile_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/profile.dart';
import 'package:o_house/theme.dart';
import 'package:o_house/widgets/app_header.dart';
import 'package:o_house/widgets/brand_logo.dart';
import 'package:signature/signature.dart';

/// Every screen's ink header is supposed to be the same depth. That is a
/// claim about five screens at once, and nothing in the type system holds it
/// — a screen that grows a second line of subtitle just quietly drifts.
///
/// The logo is the other claim worth pinning: it sits in one corner across
/// every screen, except that a close button takes that exact corner instead
/// on the three screens that have one — the two never appear together.
///
/// So both are asserted directly: pump each screen, measure the header, and
/// require one number and one occupant of that corner.
const _profile = Profile(
  id: 'u1',
  name: 'Joseph Marzouk',
  phone: '+20 100 442 7318',
  role: 'cleaner',
  locale: 'en',
  active: true,
  mustChangePassword: false,
);

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
        currentProfileProvider.overrideWith((ref) => _profile),
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

/// 'demo-1' is the in-progress round; 'demo-4' is submitted, so it is the one
/// that has a signature to review.
final _screensWithLogo = <String, Widget>{
  'Tasks': const TasksListScreen(),
  'Profile': const ProfileScreen(),
};

final _screensWithClose = <String, Widget>{
  'Task detail': const TaskDetailScreen(assignmentId: 'demo-1'),
  'Signature': const SignatureScreen(assignmentId: 'demo-1'),
  'Submission review': const HistoryDetailScreen(assignmentId: 'demo-4'),
};

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets('every header is the same height in $locale', (tester) async {
      final heights = <String, double>{};
      for (final entry in [
        ..._screensWithLogo.entries,
        ..._screensWithClose.entries,
      ]) {
        await _pump(tester, entry.value, locale: locale);
        heights[entry.key] = tester.getSize(find.byType(AppHeader)).height;
      }

      // No status-bar inset in a test view, so the header is exactly the
      // standard content height — nothing has outgrown it.
      expect(heights.values.toSet(), {
        kHeaderContentHeight,
      }, reason: 'headers drifted apart: $heights');
    });

    testWidgets('the logo sits in one corner on every screen in $locale', (
      tester,
    ) async {
      for (final entry in _screensWithLogo.entries) {
        await _pump(tester, entry.value, locale: locale);
        expect(
          find.descendant(
            of: find.byType(AppHeader),
            matching: find.byType(BrandLogo),
          ),
          findsOneWidget,
          reason: '${entry.key} is missing its logo',
        );
      }
    });

    testWidgets('a close button takes the logo\'s corner instead, in $locale', (
      tester,
    ) async {
      for (final entry in _screensWithClose.entries) {
        await _pump(tester, entry.value, locale: locale);
        final header = find.byType(AppHeader);
        // The two never share the corner — a close button means no logo.
        expect(
          find.descendant(of: header, matching: find.byType(BrandLogo)),
          findsNothing,
          reason: '${entry.key} shows the logo alongside its close button',
        );
        expect(
          find.descendant(of: header, matching: find.byIcon(Icons.close)),
          findsOneWidget,
          reason: '${entry.key} is missing its close button',
        );
      }
    });
  }

  test('Home matches by sharing the constant rather than the widget', () {
    // Home cannot use AppHeader — its ink block animates up from the splash,
    // so it is an AnimatedContainer with a full-screen overlay on top. It
    // stays in step through this constant instead.
    expect(kHomeHeaderContentHeight, kHeaderContentHeight);
  });

  group('submission flow', () {
    testWidgets('success names the round and offers the review link', (
      tester,
    ) async {
      await _pump(tester, const SuccessScreen(assignmentId: 'demo-4'));

      expect(find.text('Submitted for review'), findsOneWidget);
      expect(
        find.textContaining('Evening close — Squash court'),
        findsOneWidget,
      );
      expect(find.textContaining('Your supervisor'), findsOneWidget);
      expect(find.text('View submission'), findsOneWidget);
    });

    testWidgets('the review screen is read-only — no checkbox, no submit', (
      tester,
    ) async {
      await _pump(tester, const HistoryDetailScreen(assignmentId: 'demo-4'));

      expect(find.text('Sweep the floor'), findsOneWidget);
      expect(find.textContaining('CHECKLIST'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the review screen renders in Arabic', (tester) async {
      await _pump(
        tester,
        const HistoryDetailScreen(assignmentId: 'demo-4'),
        locale: 'ar',
      );

      expect(find.text('كنس الأرضية'), findsOneWidget);
    });

    testWidgets(
      'closing the review screen lands on tasks, never back on success',
      (tester) async {
        // A plain `home:` MaterialApp has no route stack, so canPop() is
        // always false there and can't tell an old bug from a fix. This
        // rebuilds the actual shape of the bug: Success pushes the review
        // screen, so a pop would resurface Success underneath it.
        final router = GoRouter(
          initialLocation: '/success',
          routes: [
            GoRoute(
              path: '/success',
              builder: (_, _) => const Scaffold(body: Text('SUCCESS_SCREEN')),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) =>
                  const HistoryDetailScreen(assignmentId: 'demo-4'),
            ),
            GoRoute(
              path: '/tasks',
              builder: (_, _) => const Scaffold(body: Text('TASKS_SCREEN')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              myAssignmentsProvider.overrideWith((ref) => demoAssignments()),
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

        router.push('/history');
        await tester.pumpAndSettle();
        expect(find.byType(HistoryDetailScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('TASKS_SCREEN'), findsOneWidget);
        expect(find.text('SUCCESS_SCREEN'), findsNothing);
      },
    );
  });

  group('signature', () {
    testWidgets('Clear and Submit are the same size', (tester) async {
      await _pump(tester, const SignatureScreen(assignmentId: 'demo-1'));

      final clear = tester.getSize(find.byType(OutlinedButton));
      final submit = tester.getSize(find.byType(FilledButton));
      expect(clear, submit);
    });

    // 420 is a decision, not a drift: artboard 1g draws the pad at 250, and
    // this screen deliberately departs from that artboard already — the
    // design shows Clear as an inline ghost link, the code makes it the
    // paired button asserted above. The number to match is the screen's own
    // cap (signature_screen.dart), which the Signature widget sits 2px inside
    // of, once for each edge of the container's border.
    testWidgets('the pad is capped rather than filling the screen', (
      tester,
    ) async {
      await _pump(tester, const SignatureScreen(assignmentId: 'demo-1'));

      expect(
        tester.getSize(find.byType(Signature)).height,
        lessThanOrEqualTo(420),
      );
    });
  });
}
