import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_house/data/fixtures.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/features/assignments/detail_screen.dart';
import 'package:o_house/features/assignments/history_detail_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/assignment.dart';

/// FIELD-08 / F-44: a round that isn't on this phone ends in a message with a
/// way back once the list has loaded, never an endless spinner.
Future<void> _pump(WidgetTester tester, Widget screen, FutureOr<List<Assignment>> Function() rounds) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userIdProvider.overrideWithValue(null),
        myAssignmentsProvider.overrideWith((ref) async => rounds()),
        outboxCountProvider.overrideWith((ref) => 0),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
}

void main() {
  for (final (name, screen) in [
    ('detail', const TaskDetailScreen(assignmentId: 'not-on-this-phone')),
    ('history', const HistoryDetailScreen(assignmentId: 'not-on-this-phone')),
  ]) {
    testWidgets('$name: a round missing from the loaded list says so, with Back', (tester) async {
      await _pump(tester, screen, demoAssignments);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('This checklist is no longer assigned to you'), findsOneWidget);
      expect(find.text('Back to tasks'), findsOneWidget);
    });

    testWidgets('$name: while the list is still loading it is a spinner', (tester) async {
      final never = Completer<List<Assignment>>();
      await _pump(tester, screen, () => never.future);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('This checklist is no longer assigned to you'), findsNothing);
    });
  }
}
