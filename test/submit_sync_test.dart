import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:o_house/data/api_client.dart';
import 'package:o_house/data/assignments_repo.dart';
import 'package:o_house/data/fixtures.dart';
import 'package:o_house/data/local_db.dart';
import 'package:o_house/data/providers.dart';
import 'package:o_house/data/sync.dart';
import 'package:o_house/features/assignments/signature_screen.dart';
import 'package:o_house/l10n/app_localizations.dart';
import 'package:o_house/models/profile.dart';
import 'package:o_house/theme.dart';
import 'package:signature/signature.dart';

/// Signing a round queues its submit and asks the outbox to send it. What
/// happens next must be honest:
///
///  * sent → the success screen, built on the server's re-read verdict;
///  * refused → no success screen; the reason, and Home, where the banner
///    lists it with Retry and Dismiss;
///  * still going (offline) → the success screen's "saved on this phone" face
///    (success_screen.dart), never a claim that it was submitted.
///
/// The drain itself is tested against fakes in outbox_test.dart.

/// Counts drains and records whether the round had been queued first.
class _SpySync extends SyncService {
  _SpySync(this._repo)
    : super(
        db: _repo.db,
        api: _repo.api,
        userId: 'u1',
        evidenceDir: _repo.evidence,
      );
  final _RecordingRepo _repo;

  int drains = 0;
  int submittedWhenDrained = -1;

  /// Fetches of the round list, and how many there had been by the time the
  /// success screen was first built.
  int fetches = 0;
  int? fetchesAtSuccess;

  @override
  Future<void> drain() async {
    drains++;
    submittedWhenDrained = _repo.submits;
  }
}

/// Stands in for the real repo so nothing reaches sqflite or the network.
class _RecordingRepo extends AssignmentsRepo {
  _RecordingRepo({this.parked})
    : super(
        db: LocalDb.named('unused.db'),
        api: ApiClient(
          baseUrl: 'http://unused',
          club: 'c',
          token: () => null,
          refreshSession: () async => false,
        ),
        userId: 'u1',
        evidence: () async => Directory.systemTemp,
      );

  /// What parkedCode() reports after the drain, or null for "not refused".
  final String? parked;
  int submits = 0;
  String? note;

  @override
  Future<void> submit(
    String assignmentId,
    Uint8List signaturePng, {
    String? note,
  }) async {
    submits++;
    this.note = note;
  }

  @override
  Future<String?> parkedCode(String assignmentId) async => parked;
}

const _profile = Profile(
  id: 'u1',
  name: 'Joseph Marzouk',
  phone: '+20 100 442 7318',
  role: 'cleaner',
  locale: 'en',
  active: true,
  mustChangePassword: false,
);

Future<(_SpySync, _RecordingRepo)> _pumpSignature(
  WidgetTester tester, {
  String? parked,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);

  final repo = _RecordingRepo(parked: parked);
  final sync = _SpySync(repo);

  // _submit ends in context.go(...), so the screen needs a real router.
  final router = GoRouter(
    initialLocation: '/sig',
    routes: [
      GoRoute(
        path: '/sig',
        builder: (_, _) => const SignatureScreen(assignmentId: 'demo-1'),
      ),
      GoRoute(
        path: '/tasks/:id/success',
        builder: (_, _) {
          sync.fetchesAtSuccess ??= sync.fetches;
          return const Scaffold(body: Text('success'));
        },
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assignmentsRepoProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWithValue(sync),
        roundsRefreshProvider.overrideWith((ref) {
          sync.fetches++;
          return DateTime.now();
        }),
        myAssignmentsProvider.overrideWith((ref) => demoAssignments()),
        currentProfileProvider.overrideWith((ref) => _profile),
      ],
      child: MaterialApp.router(
        theme: buildTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (sync, repo);
}

/// The pad refuses an empty signature, so draw one first. A drag across the
/// canvas is what the real user does and what _controller.isEmpty checks.
Future<void> _sign(WidgetTester tester) async {
  final pad = find.byType(Signature);
  expect(pad, findsOneWidget, reason: 'the signature pad should be on screen');
  await tester.drag(pad, const Offset(60, 30));
  await tester.pumpAndSettle();
}

/// _submit's first await is _controller.toPngBytes(), which goes through
/// picture.toImage() — real async work the widget tester's fake clock never
/// completes, so a plain pump leaves _submitting stuck true and pumpAndSettle
/// dies on the spinner rather than on anything real. runAsync gives that call
/// a live event loop; the pumps around it flush the frames.
///
/// Polls for the outcome instead of sleeping a fixed span: a flat wait long
/// enough for a loaded machine is wasted on every green run.
Future<void> _tapSubmit(
  WidgetTester tester,
  _SpySync sync, {
  bool expectDrain = true,
}) async {
  await tester.runAsync(() async {
    // By type, not by label — the button's text is localized.
    await tester.tap(find.byType(FilledButton));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump();
      if (expectDrain && sync.drains > 0) break;
      if (!expectDrain) break; // nothing async to wait on — _submit returned
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    // A few more frames so the snackbar or the next route is actually built.
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
}

void main() {
  testWidgets('submitting a signed round queues it, then drains', (
    tester,
  ) async {
    final (sync, _) = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(sync.drains, 1);
    expect(
      sync.submittedWhenDrained,
      1,
      reason: 'draining before the submit is enqueued would send nothing',
    );
  });

  testWidgets('a sent round goes to success, built on the re-read', (
    tester,
  ) async {
    final (sync, _) = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    // The success screen picks its face (submitted or follow_up) from the
    // server's verdict, so the refresh has to land before it is built.
    expect(find.text('success'), findsOneWidget);
    expect(sync.fetchesAtSuccess, 1);
  });

  // The lie that hid the original bug: "Submitted for review" while the
  // server had refused it. A refusal parks the round and says why.
  testWidgets('a refused round reports why instead of claiming success', (
    tester,
  ) async {
    final (sync, _) = await _pumpSignature(
      tester,
      parked: 'ASSIGNMENT_EXPIRED',
    );
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(find.text('success'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(find.textContaining('extend'), findsOneWidget); // refusalExpired
  });

  testWidgets('the note for the supervisor travels with the submit', (
    tester,
  ) async {
    final (sync, repo) = await _pumpSignature(tester);
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tap in room 3 leaks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sticky_note_2), findsOneWidget);

    await _sign(tester);
    await _tapSubmit(tester, sync);
    expect(repo.note, 'Tap in room 3 leaks');
  });

  testWidgets('an empty pad neither submits nor drains', (tester) async {
    final (sync, repo) = await _pumpSignature(tester);
    await _tapSubmit(tester, sync, expectDrain: false);

    expect(sync.drains, 0);
    expect(repo.submits, 0);
  });
}
