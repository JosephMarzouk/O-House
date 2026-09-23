import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// The one thing standing between a signed round and Supabase.
///
/// Every repo write only enqueues; SyncService.drain() is the only code that
/// replays the queue, and its other trigger is a connectivity *change* that
/// never comes on a phone which is online and stays online. So "the submit
/// button eventually reaches the server" rests entirely on the signature
/// screen calling drain() itself — a single line whose absence is invisible
/// (the success screen still shows) and cost a whole phase of submissions.
///
/// Order matters as much as the call: drain has to finish BEFORE the provider
/// is invalidated, or the refresh reads a server that has not been sent
/// anything yet. That is asserted directly rather than trusted.
///
/// The upload path and the RPCs themselves stay manual — there is no fake
/// Supabase client in this project yet (see outbox_test's note).

/// Counts drains and records whether the round had been queued first.
/// Same idiom as home_screen_test's _NoopSync: subclass SyncService rather
/// than introduce an interface for one test.
class _SpySync extends SyncService {
  _SpySync(this._repo, {this.failWith}) : super(LocalDb.instance);
  final _RecordingRepo _repo;

  /// What drain() should report as having gone wrong, or null for a clean run.
  final String? failWith;

  int drains = 0;
  int submittedWhenDrained = -1;
  String? watched;

  /// Fetches of the round list, and how many there had been by the time the
  /// success screen was first built. Kept here because this spy is already
  /// the one handle each test holds.
  int fetches = 0;
  int? fetchesAtSuccess;

  @override
  Future<void> start() async {}

  @override
  Future<void> drain({String? watch}) async {
    drains++;
    submittedWhenDrained = _repo.submits;
    watched = watch;
    lastError = failWith;
  }
}

/// Stands in for the real repo so nothing reaches sqflite, which has no test
/// binding. The base _pump harnesses elsewhere override neither this nor
/// syncServiceProvider — a tap there would hit the real database.
class _RecordingRepo extends AssignmentsRepo {
  _RecordingRepo() : super(LocalDb.instance);

  int submits = 0;
  String? signaturePath;

  @override
  Future<void> submit(String assignmentId, String localSignaturePath) async {
    submits++;
    signaturePath = localSignaturePath;
  }
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

/// _submit writes the signature PNG through getTemporaryDirectory(), and
/// path_provider has no binding under `flutter test` — an unhandled
/// MissingPluginException there leaves _submitting stuck true, so the button's
/// CircularProgressIndicator spins and pumpAndSettle times out instead of
/// reporting anything useful. Hand it the real system temp dir.
void _stubPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
  );
}

Future<_SpySync> _pumpSignature(
  WidgetTester tester, {
  String? drainFails,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(410, 864);
  addTearDown(tester.view.reset);
  _stubPathProvider();

  final repo = _RecordingRepo();
  final sync = _SpySync(repo, failWith: drainFails);

  // _submit ends in context.go('/tasks/:id/success'), so the screen needs a
  // real router under it — MaterialApp(home:) alone throws on the way out.
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
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assignmentsRepoProvider.overrideWithValue(repo),
        syncServiceProvider.overrideWithValue(sync),
        myAssignmentsProvider.overrideWith((ref) {
          sync.fetches++;
          return demoAssignments();
        }),
        currentProfileProvider.overrideWith((ref) => _profile),
        outboxCountProvider.overrideWith((ref) => 0),
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
  return sync;
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
/// Polls for the outcome instead of sleeping a fixed span. A flat 400ms passed
/// this file in isolation and failed in the full run, where isolates compete
/// for CPU and the PNG encode takes longer — a wait long enough to be reliable
/// on a loaded machine is also long enough to be wasted on every green run.
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
    // One more frame so the snackbar or the success route is actually built.
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  });
}

void main() {
  testWidgets('submitting a signed round drains the outbox', (tester) async {
    final sync = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(
      sync.drains,
      1,
      reason: 'without this the round only leaves the device on a later launch',
    );
  });

  testWidgets('the drain happens after the round is queued, not before', (
    tester,
  ) async {
    final sync = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(
      sync.submittedWhenDrained,
      1,
      reason: 'draining before the submit is enqueued would send nothing',
    );
  });

  testWidgets('the drain is scoped to the round being submitted', (
    tester,
  ) async {
    final sync = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    // Otherwise flushing an older round's dead rows would surface as this
    // round's failure and hide a submit that actually worked.
    expect(sync.watched, 'demo-1');
  });

  testWidgets('a clean drain advances to the success screen', (tester) async {
    final sync = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(find.text('success'), findsOneWidget);
  });

  // The success screen picks its face — "submitted for review" or "needs
  // follow-up" — from the round's status, and only the server knows which it
  // is once it has judged the answers. A bare invalidate here let it paint the
  // stale status first; nothing had re-read the round by the time it built.
  testWidgets('the round is re-read before the success screen is built', (
    tester,
  ) async {
    final sync = await _pumpSignature(tester);
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(find.text('success'), findsOneWidget);
    expect(
      sync.fetchesAtSuccess,
      1,
      reason: 'the success screen must be built on the post-submit re-read',
    );
  });

  // The lie that hid the original bug: the round read "Submitted for review"
  // while the queue had stopped dead and the server had never heard of it.
  testWidgets('a failed drain reports instead of claiming success', (
    tester,
  ) async {
    final sync = await _pumpSignature(
      tester,
      drainFails: 'mark_item_done failed: boom',
    );
    await _sign(tester);
    await _tapSubmit(tester, sync);

    expect(
      find.text('success'),
      findsNothing,
      reason: 'a round that did not land must not show the success screen',
    );
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('an empty pad neither submits nor drains', (tester) async {
    final sync = await _pumpSignature(tester);
    await _tapSubmit(tester, sync, expectDrain: false);

    expect(sync.drains, 0);
    expect(sync.submittedWhenDrained, -1);
  });
}
