import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assignment.dart';
import '../../models/assignment_item.dart';
import '../../widgets/status_chip.dart';
import 'item_sheet.dart';

/// §6, screen 6. Read-only once effective_status is submitted/approved/
/// expired (Assignment.isReadOnly) — an expired task shows the locked
/// message from §13 instead of the submit bar.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final assignment = ref.watch(assignmentByIdProvider(assignmentId));

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    final title = locale == 'ar' && assignment.titleAr.isNotEmpty
        ? assignment.titleAr
        : assignment.titleEn;
    final progress = assignment.items.isEmpty
        ? 0.0
        : assignment.doneCount / assignment.items.length;

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? assignment.titleEn : title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (assignment.windowStart != null &&
                        assignment.windowEnd != null)
                      Text(
                        t.taskDetailWindow(
                          assignment.windowStart!.substring(0, 5),
                          assignment.windowEnd!.substring(0, 5),
                        ),
                      ),
                    StatusChip(
                      status: assignment.effectiveStatus,
                      wasExtended: assignment.wasExtended,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: assignment.items.length,
              itemBuilder: (context, i) => _ItemRow(
                assignment: assignment,
                item: assignment.items[i],
                readOnly: assignment.isReadOnly,
              ),
            ),
          ),
          _BottomBar(assignment: assignment),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.assignment,
    required this.item,
    required this.readOnly,
  });
  final Assignment assignment;
  final AssignmentItem item;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final text = locale == 'ar' && item.textAr.isNotEmpty
        ? item.textAr
        : item.textEn;
    final done = item.status == 'done';
    final rejected = item.status == 'rejected';

    return Consumer(
      builder: (context, ref, _) => ListTile(
        onTap: readOnly
            ? null
            : () => showItemSheet(
                context,
                ref,
                assignmentId: assignment.id,
                item: item,
              ),
        leading: Icon(
          rejected
              ? Icons.error_outline
              : done
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: rejected ? Colors.red : (done ? Colors.green : null),
        ),
        title: Text(
          text,
          style: item.critical
              ? const TextStyle(fontWeight: FontWeight.w600)
              : null,
        ),
        subtitle: rejected && item.rejectNote != null
            ? Text(
                t.taskDetailRejectedReason(item.rejectNote!),
                style: const TextStyle(color: Colors.red),
              )
            : (item.requiresPhoto
                  ? Text(
                      t.taskDetailPhotoRequired,
                      style: const TextStyle(fontSize: 12),
                    )
                  : null),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.assignment});
  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    if (assignment.effectiveStatus == 'expired') {
      return _Bar(
        child: Text(t.taskDetailExpiredMessage, textAlign: TextAlign.center),
      );
    }
    if (assignment.isReadOnly) return const SizedBox.shrink();

    return _Bar(
      child: FilledButton(
        onPressed: assignment.canSubmit
            ? () => context.push('/tasks/${assignment.id}/signature')
            : null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(t.taskDetailSubmitButton),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
