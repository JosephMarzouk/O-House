import 'package:uuid/uuid.dart';

import '../models/assignment.dart';
import '../models/assignment_item.dart';
import '../supabase.dart';
import 'fixtures.dart';
import 'local_db.dart';

/// The one seam — no screen touches Supabase directly (§8). Reads come off
/// the server and are mirrored into the cache on the way past, which is what
/// Phase 3 will read from once offline reads land; writes go to the outbox.
///
/// It is also where [kDemoData] branches, for the same reason: with the flag
/// on, reads and writes hit an in-memory fixture list instead, and every
/// screen, provider and widget above this line behaves identically. sqflite
/// and path_provider have no web support, so the demo path deliberately
/// avoids both and works in the browser preview.
class AssignmentsRepo {
  AssignmentsRepo(this._db);
  final LocalDb _db;
  static const _uuid = Uuid();

  /// Static so ticks survive the provider rebuild that follows every
  /// invalidate — assignmentsRepoProvider is a plain Provider and gets
  /// reconstructed whenever its dependencies change.
  static List<Assignment>? _demo;
  static List<Assignment> get _demoList => _demo ??= demoAssignments();

  // ---- reads: local cache only ------------------------------------------

  Future<List<Assignment>> myAssignments() async {
    if (kDemoData) return List.of(_demoList);
    final cached = await _db.allCachedAssignments();
    return cached.map(Assignment.fromJson).toList()..sort(
      (a, b) => (a.scheduledDate ?? DateTime(0)).compareTo(
        b.scheduledDate ?? DateTime(0),
      ),
    );
  }

  // ---- refresh: pull assignments_v + assignment_items, replace cache ----
  // Online-only for now (Phase 1); outbox replay lands in Phase 3.

  Future<List<Assignment>> refreshFromServer(String assigneeId) async {
    if (kDemoData) return List.of(_demoList);
    final rows = await supabase
        .from('assignments_v')
        .select()
        .eq('inspector_id', assigneeId)
        .order('scheduled_date');

    final assignments = <Assignment>[];
    for (final row in rows as List) {
      final assignment = Assignment.fromJson(row as Map<String, dynamic>);
      final itemRows = await supabase
          .from('assignment_items')
          .select()
          .eq('assignment_id', assignment.id)
          .order('sort_order');
      final items = (itemRows as List)
          .map((r) => AssignmentItem.fromJson(r as Map<String, dynamic>))
          .toList();
      assignments.add(assignment.copyWithItems(items));
    }

    // Best-effort, for the same reason locale_provider guards its reads: with
    // no sqflite platform (web preview, headless tests) this throws, and
    // dropping the rows we just fetched over a cache miss is the worse
    // failure. The list the UI renders is the one above, not the cache.
    try {
      for (final a in assignments) {
        await _db.upsertAssignment(a.id, a.toCacheJson());
      }
    } catch (_) {}

    return assignments;
  }

  // ---- writes: local + outbox, one RPC per queued op (§2, §8) -----------

  Future<void> markItemDone(
    String assignmentId,
    String itemId, {
    String? note,
  }) async {
    if (kDemoData) {
      _patchItem(
        assignmentId,
        itemId,
        (i) => AssignmentItem.fromJson({
          ...i.toJson(),
          'status': 'done',
          'done_at': DateTime.now().toIso8601String(),
          'note': note ?? i.note,
          'reject_note': null,
        }),
      );
      // Same parent transition mark_item_done() makes server-side.
      _patchAssignment(assignmentId, (a) {
        if (a.effectiveStatus != 'pending') return a;
        return _withStatus(a, 'in_progress');
      });
      return;
    }
    await _db.enqueue(
      id: _uuid.v4(),
      assignmentId: assignmentId,
      op: 'mark_item_done',
      payload: {'p_item_id': itemId, 'p_note': note},
    );
    // Optimistic local update so the UI reflects it before sync drains.
    // TODO(phase-3): update the cached assignment's item status in place.
  }

  Future<void> attachItemPhoto(
    String assignmentId,
    String itemId,
    String localFilePath,
  ) async {
    if (kDemoData) {
      _patchItem(
        assignmentId,
        itemId,
        // array_append, matching attach_item_photo()'s idempotency guard —
        // photos are never removed or replaced, only added to.
        (i) => i.photoPaths.contains(localFilePath)
            ? i
            : AssignmentItem.fromJson({
                ...i.toJson(),
                'photo_paths': [...i.photoPaths, localFilePath],
              }),
      );
      return;
    }
    // TODO(phase-2): compress via flutter_image_compress before queuing —
    // 10 staff x 40 places x one 4MB photo is 1.6GB/day uncompressed (§9).
    await _db.enqueue(
      id: _uuid.v4(),
      assignmentId: assignmentId,
      op: 'attach_item_photo',
      payload: {'p_item_id': itemId, 'local_file_path': localFilePath},
    );
  }

  Future<void> submit(String assignmentId, String localSignaturePath) async {
    if (kDemoData) {
      _patchAssignment(
        assignmentId,
        (a) => _withStatus(a, 'submitted', signatureUrl: localSignaturePath),
      );
      return;
    }
    await _db.enqueue(
      id: _uuid.v4(),
      assignmentId: assignmentId,
      op: 'submit_assignment',
      payload: {
        'local_signature_path': localSignaturePath,
        'completed_at': DateTime.now().toIso8601String(),
        'client_op_id': _uuid.v4(), // idempotency across retries, see §3
      },
    );
  }

  // ---- demo-mode mutation ------------------------------------------------
  // Rebuilds through the existing toJson/fromJson round trip rather than a
  // copyWith the production path would never call.

  void _patchAssignment(String id, Assignment Function(Assignment) f) {
    final i = _demoList.indexWhere((a) => a.id == id);
    if (i >= 0) _demoList[i] = f(_demoList[i]);
  }

  void _patchItem(
    String assignmentId,
    String itemId,
    AssignmentItem Function(AssignmentItem) f,
  ) {
    _patchAssignment(
      assignmentId,
      (a) =>
          a.copyWithItems([for (final i in a.items) i.id == itemId ? f(i) : i]),
    );
  }

  static Assignment _withStatus(
    Assignment a,
    String status, {
    String? signatureUrl,
  }) => Assignment.fromJson({
    ...a.toCacheJson(),
    'status': status,
    'effective_status': status,
    if (status == 'submitted') 'submitted_at': DateTime.now().toIso8601String(),
    'signature_url': ?signatureUrl,
  });
}
