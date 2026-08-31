import 'package:uuid/uuid.dart';

import '../models/assignment.dart';
import '../models/assignment_item.dart';
import '../supabase.dart';
import 'local_db.dart';

/// The one seam — no screen touches Supabase directly (§8). Reads always
/// come from the local cache; writes land in the cache *and* the outbox in
/// the same breath. Whether the network exists is invisible to the UI.
class AssignmentsRepo {
  AssignmentsRepo(this._db);
  final LocalDb _db;
  static const _uuid = Uuid();

  // ---- reads: local cache only ------------------------------------------

  Future<List<Assignment>> myAssignments() async {
    final cached = await _db.allCachedAssignments();
    return cached.map(Assignment.fromJson).toList()..sort(
      (a, b) => (a.scheduledDate ?? DateTime(0)).compareTo(
        b.scheduledDate ?? DateTime(0),
      ),
    );
  }

  // ---- refresh: pull assignments_v + assignment_items, replace cache ----
  // Online-only for now (Phase 1); outbox replay lands in Phase 3.

  Future<void> refreshFromServer(String assigneeId) async {
    final rows = await supabase
        .from('assignments_v')
        .select()
        .eq('inspector_id', assigneeId)
        .order('scheduled_date');

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
      await _db.upsertAssignment(
        assignment.id,
        assignment.copyWithItems(items).toCacheJson(),
      );
    }
  }

  // ---- writes: local + outbox, one RPC per queued op (§2, §8) -----------

  Future<void> markItemDone(
    String assignmentId,
    String itemId, {
    String? note,
  }) async {
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
}
