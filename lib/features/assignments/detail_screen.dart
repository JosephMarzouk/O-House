import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/assignment.dart';
import '../../models/assignment_item.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_snack.dart';
import '../../widgets/subtask_tile.dart';
import '../../widgets/task_progress_bar.dart';

/// A subtask counts as ticked if it was already done on the server or the user
/// has ticked it this session. Nothing is written until Submit & Sign, so the
/// staged set is the only place a fresh tick lives.
bool isItemChecked(AssignmentItem i, Set<String> staged) =>
    i.status == 'done' || staged.contains(i.id);

List<String> itemPhotos(AssignmentItem i, Map<String, List<String>> staged) => [
  ...i.photoPaths,
  ...?staged[i.id],
];

/// Ticked places that still owe a photo. Drives both the submit gate and the
/// caption under the disabled button.
int missingPhotoCount(
  Assignment a,
  Set<String> checked,
  Map<String, List<String>> newPhotos,
) => a.items
    .where(
      (i) =>
          isItemChecked(i, checked) &&
          i.requiresPhoto &&
          itemPhotos(i, newPhotos).isEmpty,
    )
    .length;

/// Every subtask the user actually ticked that requires a photo must have one.
/// Unticked subtasks are simply left not-done — they do not block submission.
///
/// Deliberately not Assignment.canSubmit, which encodes the all-done rule.
///
/// submit_assignment() agrees with this gate as of 0006_partial_submit.sql —
/// it requires at least one done item and evidence only from the items
/// claimed done, not from every item on the round.
bool canSubmitStaged(
  Assignment a,
  Set<String> checked,
  Map<String, List<String>> newPhotos,
) {
  final anyChecked = a.items.any((i) => isItemChecked(i, checked));
  return anyChecked && missingPhotoCount(a, checked, newPhotos) == 0;
}

/// §6, screen 6 — artboard 1d. Read-only once effective_status is submitted/
/// approved/expired (Assignment.isReadOnly); an expired task shows the locked
/// message from §13 instead of the submit bar.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  /// Ticks made this session, not yet written anywhere.
  final Set<String> _checked = {};

  /// itemId -> local file paths captured this session.
  final Map<String, List<String>> _newPhotos = {};

  bool _submitting = false;

  Future<void> _takePhoto(AssignmentItem item) async {
    // Camera only, never the gallery — a photo from the gallery is not
    // evidence of anything (§9). Compression lands in Phase 2.
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _newPhotos.putIfAbsent(item.id, () => []).add(picked.path));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final repo = ref.read(assignmentsRepoProvider);

    // Nothing here used to be guarded, and every one of these calls writes to
    // sqflite. A throw left _submitting stuck true — so the button showed a
    // spinner forever, never navigated, and the only way out was backing out
    // to the list, which rebuilt the screen with _submitting false and made it
    // look like Submit simply did nothing, over and over, with the real
    // exception nowhere the user could see it.
    try {
      // Photos first, so each item satisfies its requires_photo check by the
      // time it is marked done.
      for (final entry in _newPhotos.entries) {
        for (final path in entry.value) {
          await repo.attachItemPhoto(widget.assignmentId, entry.key, path);
        }
      }
      for (final itemId in _checked) {
        await repo.markItemDone(widget.assignmentId, itemId);
      }
    } catch (e, s) {
      debugPrint('[submit] queueing failed: $e\n$s');
      if (mounted) {
        setState(() => _submitting = false);
        showErrorSnack(context, 'Could not save this round: $e');
      }
      return;
    }
    ref.invalidate(myAssignmentsProvider);

    if (!mounted) return;
    // Committed before the signature route rather than threaded through it —
    // backing out of signing should not throw the round away.
    await context.push('/tasks/${widget.assignmentId}/signature');
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final assignment = ref.watch(assignmentByIdProvider(widget.assignmentId));

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final readOnly = assignment.isReadOnly;
    final done = assignment.items
        .where((i) => isItemChecked(i, _checked))
        .length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _Header(assignment: assignment, done: done),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                itemCount: assignment.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = assignment.items[i];
                  // A tick already on the server cannot be taken back; only
                  // this session's ticks are reversible.
                  final locked = readOnly || item.status == 'done';
                  return SubtaskTile(
                    item: item,
                    checked: isItemChecked(item, _checked),
                    locked: locked,
                    photos: itemPhotos(item, _newPhotos),
                    onToggle: () => setState(() {
                      if (!_checked.remove(item.id)) _checked.add(item.id);
                    }),
                    onCamera: () => _takePhoto(item),
                  );
                },
              ),
            ),
            _BottomBar(
              assignment: assignment,
              checked: _checked,
              newPhotos: _newPhotos,
              submitting: _submitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.assignment, required this.done});
  final Assignment assignment;
  final int done;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final a = assignment;

    return AppHeader(
      title: pickLocalized(context, a.titleAr, a.titleEn),
      subtitle: assignmentSubtitle(context, a),
      actions: [
        HeaderIconButton(
          icon: Icons.close,
          label: MaterialLocalizations.of(context).closeButtonLabel,
          // A deep link straight to a task has nothing to pop back to.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/tasks'),
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.taskDetailProgressLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Color(0xB3F3F2F2), // paper @ 70%
                  ),
                ),
                Text(
                  t.tasksProgress(done, a.items.length),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paper,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            TaskProgressBar(
              done: done,
              total: a.items.length,
              height: 8,
              track: TaskProgressBar.onInkTrack,
              fill: TaskProgressBar.fillFor(a.effectiveStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.assignment,
    required this.checked,
    required this.newPhotos,
    required this.submitting,
    required this.onSubmit,
  });

  final Assignment assignment;
  final Set<String> checked;
  final Map<String, List<String>> newPhotos;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (assignment.effectiveStatus == 'expired') {
      return _Bar(
        child: Text(
          t.taskDetailExpiredMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: AppColors.magenta),
        ),
      );
    }
    if (assignment.isReadOnly) return const SizedBox.shrink();

    final missing = missingPhotoCount(assignment, checked, newPhotos);
    final canSubmit = canSubmitStaged(assignment, checked, newPhotos);

    return _Bar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: canSubmit && !submitting ? onSubmit : null,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.draw_outlined, size: 22),
                      const SizedBox(width: 8),
                      Text(t.taskDetailSubmitButton),
                    ],
                  ),
          ),
          if (missing > 0) ...[
            const SizedBox(height: 10),
            Text(
              t.taskDetailPhotosMissing(missing),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: Color(0x80201E1D), // text @ 50%
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: child,
      ),
    ),
  );
}
