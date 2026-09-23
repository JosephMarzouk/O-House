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

    // Used to be the person's entire history, one items query per round,
    // one after another — fine at a handful of rows, not once every zone
    // round became one task per place. It also pulled the old inspector
    // client's undated rows (scheduled_date NULL, most of the table) into
    // Today; NULL fails the gte below, and those rows are never follow_up.
    //
    // ponytail: a 7-day look-back. A round older than that vanishes from the
    // app unless it is in follow_up, which never expires and is the one kind
    // of old round still waiting on this person. An older round sent back as
    // in_progress or rejected drops off with the rest — widen the window, or
    // add those statuses to the or-filter, if that ever bites.
    //
    // Raw `status` in the filter, against the read-effective_status rule, on
    // purpose: follow_up is written, never derived from the clock, so the
    // two columns agree on it by construction (see assignments_v).
    final since = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10); // yyyy-MM-dd, local — a day's drift is harmless
    final rows = await supabase
        .from('assignments_v')
        .select()
        .eq('inspector_id', assigneeId)
        .or('scheduled_date.gte.$since,status.eq.follow_up')
        .order('scheduled_date');

    // One items request per 50 rounds, all in flight at once, instead of one
    // per round in sequence.
    //
    // ponytail: 50 ids a request stays under PostgREST's default 1000-row
    // cap only while checklists average under 20 items — the longest live
    // template has 10, so ~500 rows at worst. Past the cap a response is
    // truncated SILENTLY and items simply go missing from their rounds, so
    // shrink the chunk or page with .range() before checklists grow that
    // long.
    final ids = [for (final r in rows) r['id'] as String];
    final pages = await Future.wait([
      for (var i = 0; i < ids.length; i += 50)
        supabase
            .from('assignment_items')
            .select()
            .inFilter('assignment_id', ids.skip(i).take(50).toList())
            .order('sort_order'),
    ]);
    // Each page is sorted by sort_order and grouping keeps relative order,
    // so every round's checklist comes out in order.
    final itemsFor = <String, List<AssignmentItem>>{};
    for (final r in pages.expand((page) => page)) {
      final item = AssignmentItem.fromJson(r);
      (itemsFor[item.assignmentId] ??= []).add(item);
    }
    final assignments = [
      for (final r in rows)
        Assignment.fromJson(r).copyWithItems(itemsFor[r['id']] ?? const []),
    ];

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

  /// [answer] arrives already in wire form (normalizeAnswer in
  /// detail_screen.dart). The server decides what it means: against the
  /// item's `correct` rule it lands the item on done or follow_up.
  Future<void> markItemDone(
    String assignmentId,
    String itemId, {
    String? note,
    String? answer,
  }) async {
    if (kDemoData) {
      // Stores the answer and marks done, whatever the answer is. Whether it
      // matches the item's rule is decided only server-side, by answer_ok()
      // inside mark_item_done() (0013) — the demo has no server to ask, so it
      // never produces a follow_up of its own.
      _patchItem(
        assignmentId,
        itemId,
        (i) => AssignmentItem.fromJson({
          ...i.toJson(),
          'status': 'done',
          'done_at': DateTime.now().toIso8601String(),
          'note': note ?? i.note,
          'reject_note': null,
          'answer': answer ?? i.answer,
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
      // Queued even when null; replay leaves a null out of the call (see
      // markItemDoneParams in sync.dart for why that matters).
      payload: {'p_item_id': itemId, 'p_note': note, 'p_answer': answer},
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
