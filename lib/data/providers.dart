import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assignment.dart';
import '../models/profile.dart';
import '../tenant.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'assignments_repo.dart';
import 'local_db.dart';
import 'sync.dart';

/// Notifies on every sign-in/sign-out so the router and everything
/// user-scoped can react.
final authStateProvider = ChangeNotifierProvider<AuthService>((ref) => authService);

/// The signed-in user, or null. Everything cached or queued is keyed by it.
final userIdProvider = Provider<String?>((ref) => ref.watch(authStateProvider).userId);

final localDbProvider = Provider((ref) => LocalDb.instance);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    club: tenant.clubSlug,
    token: () => authService.accessToken,
    refreshSession: authService.refresh,
  );
});

/// Null until someone is signed in.
final assignmentsRepoProvider = Provider<AssignmentsRepo?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  return AssignmentsRepo(
    db: ref.watch(localDbProvider),
    api: ref.watch(apiClientProvider),
    userId: userId,
    evidence: evidenceDir,
  );
});

/// The outbox, for the signed-in user only, with its triggers (SY-2): created
/// on sign-in (which is also app start with a saved session), then on every
/// return to the foreground and every reconnect. Kept alive by the banner and
/// by app.dart. A different user gets a new service; the old one stops, and
/// its rows wait in the database for their owner.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return null;
  final sync = SyncService(
    db: repo.db,
    api: repo.api,
    userId: repo.userId,
    evidenceDir: repo.evidence,
    onSent: () async => ref.invalidate(roundsRefreshProvider),
  );

  final net = Connectivity().onConnectivityChanged.listen((r) {
    if (!r.contains(ConnectivityResult.none)) sync.drain();
  });
  final life = AppLifecycleListener(onResume: sync.drain);
  ref.onDispose(() {
    net.cancel();
    life.dispose();
    sync.dispose();
  });
  unawaited(sync.drain());
  return sync;
});

/// The banner's state (SY-5), live.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return const SyncStatus();
  void changed() => ref.invalidateSelf();
  sync.status.addListener(changed);
  ref.onDispose(() => sync.status.removeListener(changed));
  return sync.status.value;
});

/// Work not yet accepted by the server, parked included: Profile's pending
/// row and the sign-out warning.
final outboxCountProvider = Provider<int>((ref) {
  final s = ref.watch(syncStatusProvider);
  return s.waiting + s.parked;
});

/// Parked ops, for the "needs attention" list with Retry / Dismiss (SY-6).
final parkedOpsProvider = FutureProvider<List<OutboxOp>>((ref) async {
  ref.watch(syncStatusProvider);
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return [];
  return (await repo.db.ops(repo.userId)).where((o) => o.parked).toList();
});

/// Rounds with work on this phone that the server has not accepted yet and
/// has not refused: "saved on this phone, will send".
final pendingRoundsProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(syncStatusProvider);
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return {};
  return {
    for (final o in await repo.db.ops(repo.userId))
      if (!o.parked) o.assignmentId,
  };
});

// ---- profile: cache first, then the network (LS-3) ---------------------------

final profileFetchProvider = FutureProvider<Profile?>((ref) async {
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return null;
  final res = await repo.api.get('/me') as Map<String, dynamic>;
  final json = res['profile'] as Map<String, dynamic>;
  await repo.db.saveProfile(repo.userId, json);
  // The club's About / Policies text rides on /me; cached with the profile
  // so Profile shows it offline. Club-wide, so one settings row, not per user.
  if (res['pages'] != null) {
    await repo.db.setSetting(_clubPagesKey, jsonEncode(res['pages']));
  }
  return _withPhone(Profile.fromJson(json));
});

const _clubPagesKey = 'club_pages';

/// The club's pages written by an admin in the portal, by key (`about`,
/// `policies`): `{body_en, body_ar}`. From the cache, refreshed with the
/// profile. Empty until the first `/me` lands; the screen then shows its
/// built-in line.
final clubPagesProvider = FutureProvider<Map<String, Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(profileFetchProvider);
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return {};
  final raw = await repo.db.getSetting(_clubPagesKey);
  if (raw == null) return {};
  return {
    for (final p in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      p['key'] as String: p,
  };
});

/// The cached profile at once, replaced by the server's as soon as it lands.
/// Offline, the cache is the answer.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final fetched = ref.watch(profileFetchProvider);
  if (fetched.hasValue && fetched.value != null) return fetched.value;
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return null;
  final cached = await repo.db.profile(repo.userId);
  if (cached != null) return _withPhone(Profile.fromJson(cached));
  // Nothing cached (first sign-in on this phone): wait for the network.
  return ref.watch(profileFetchProvider.future);
});

/// The API never returns phone (admin-only); the sign-in remembers it.
Profile _withPhone(Profile p) => Profile(
  id: p.id,
  name: p.name,
  phone: authService.phone,
  role: p.role,
  locale: p.locale,
  active: p.active,
  mustChangePassword: p.mustChangePassword,
);

// ---- rounds: cache first, then the network (LS-3, LS-4) ---------------------

/// One `GET /assignments` into the cache. Invalidate it to refresh (pull to
/// refresh, after a drain). Its value is when that refresh finished.
final roundsRefreshProvider = FutureProvider<DateTime?>((ref) async {
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return null;
  await repo.refresh();
  return DateTime.now();
});

/// The signed-in user's rounds from the cache, with their queued work laid
/// over them. Recomputed when a refresh lands and whenever the outbox moves.
/// Never waits on the network, so API downtime is invisible to field work.
final myAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  ref.watch(roundsRefreshProvider);
  ref.watch(syncStatusProvider);
  final repo = ref.watch(assignmentsRepoProvider);
  if (repo == null) return [];
  return repo.cached();
});

/// When the cache was last refreshed, for "Last updated 09:12" offline.
final refreshedAtProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(roundsRefreshProvider);
  return ref.watch(assignmentsRepoProvider)?.refreshedAt();
});

/// Pull to refresh. Offline it just stops spinning; the banner says why.
Future<void> refreshRounds(WidgetRef ref) async {
  ref.invalidate(roundsRefreshProvider);
  try {
    await ref.read(roundsRefreshProvider.future);
  } catch (_) {}
  unawaited(ref.read(syncServiceProvider)?.drain());
}

/// One assignment out of the already-loaded list — no extra round trip.
final assignmentByIdProvider = Provider.family<Assignment?, String>((ref, id) {
  final list = ref.watch(myAssignmentsProvider).valueOrNull ?? [];
  for (final a in list) {
    if (a.id == id) return a;
  }
  return null;
});

/// Signed links for one round's evidence (`GET /assignments/:id`), keyed by
/// stored path. Fetched only where images are shown; empty offline.
final roundMediaProvider = FutureProvider.autoDispose
    .family<Map<String, String?>, String>((ref, id) async {
      final repo = ref.watch(assignmentsRepoProvider);
      if (repo == null) return {};
      try {
        return await repo.media(id);
      } catch (_) {
        return {};
      }
    });
