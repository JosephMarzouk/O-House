import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assignment.dart';
import '../models/profile.dart';
import '../supabase.dart';
import 'assignments_repo.dart';
import 'local_db.dart';
import 'sync.dart';

final localDbProvider = Provider((ref) => LocalDb.instance);

final assignmentsRepoProvider = Provider(
  (ref) => AssignmentsRepo(ref.watch(localDbProvider)),
);

final syncServiceProvider = Provider(
  (ref) => SyncService(ref.watch(localDbProvider)),
);

/// Drives the sync_banner widget (§6). Non-zero once offline writes land
/// in Phase 3 — always zero for now since Phase 1 is online-only.
final outboxCountProvider = FutureProvider<int>((ref) async {
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
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  final repo = ref.watch(assignmentsRepoProvider);
  await repo.refreshFromServer(profile.id);
  return repo.myAssignments();
});

/// One assignment out of the already-loaded list — no extra round trip.
final assignmentByIdProvider = Provider.family<Assignment?, String>((ref, id) {
  final list = ref.watch(myAssignmentsProvider).valueOrNull ?? [];
  for (final a in list) {
    if (a.id == id) return a;
  }
  return null;
});
