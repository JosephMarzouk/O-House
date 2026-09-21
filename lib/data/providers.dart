import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assignment.dart';
import '../models/profile.dart';
import '../supabase.dart';
import 'assignments_repo.dart';
import 'fixtures.dart';
import 'local_db.dart';
import 'sync.dart';

final localDbProvider = Provider((ref) => LocalDb.instance);

final assignmentsRepoProvider = Provider(
  (ref) => AssignmentsRepo(ref.watch(localDbProvider)),
);

final syncServiceProvider = Provider(
  (ref) => SyncService(ref.watch(localDbProvider)),
);

/// Drives the sync_banner widget (§6) and Profile's pending row.
///
/// The watch below is load-bearing, not decoration. This is a non-autoDispose
/// FutureProvider whose only other dependency is localDbProvider — a plain
/// Provider that never changes — and nothing in the app invalidates it. So it
/// used to compute once at launch, when the outbox is empty, and stay frozen
/// there: a submit made offline showed the success screen, no banner, and no
/// signal at all. Depending on myAssignmentsProvider recomputes the count
/// after every submit and every pull-to-refresh, and cannot be forgotten at a
/// call site the way a hand-written invalidate can.
final outboxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(myAssignmentsProvider);
  final ops = await ref.watch(localDbProvider).outboxOps();
  return ops.length;
});

/// Emits on every sign-in/sign-out so the router's redirect can react.
final authStateProvider = StreamProvider(
  (ref) => supabase.auth.onAuthStateChange,
);

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider); // re-run after sign-in/out
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;
  final row = await supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  return row == null ? null : Profile.fromJson(row);
});

/// Phase 1 is online-only (§10) — this hits the server directly rather
/// than reading the cache the way the post-Phase-3 repo eventually will.
final myAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  final repo = ref.watch(assignmentsRepoProvider);
  // Demo fixtures belong to nobody, so the profile gate below would hold them
  // back until a real sign-in — which is exactly what the flag exists to avoid.
  if (kDemoData) return repo.myAssignments();
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return repo.refreshFromServer(profile.id);
});

/// One assignment out of the already-loaded list — no extra round trip.
final assignmentByIdProvider = Provider.family<Assignment?, String>((ref, id) {
  final list = ref.watch(myAssignmentsProvider).valueOrNull ?? [];
  for (final a in list) {
    if (a.id == id) return a;
  }
  return null;
});
