import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/assignment.dart';
import '../../models/assignment_item.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/evidence_video.dart';
import '../../widgets/photo_thumb.dart';
import '../../widgets/status_chip.dart';

/// §6, screen 10 — artboard 1i. What was submitted, exactly as it was sent:
/// no checkboxes, no camera, no submit bar, nothing tappable in the body but
/// a video clip, which plays.
///
/// The read-only signal is the tick itself — a bare check glyph rather than a
/// filled checkbox, so there is nothing on screen that looks like it toggles.
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.assignmentId});
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

    final a = assignment;
    final locale = Localizations.localeOf(context).toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            AppHeader(
              title: pickLocalized(context, a.titleAr, a.titleEn),
              subtitle: assignmentSubtitle(context, a),
              actions: [
                HeaderIconButton(
                  icon: Icons.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  // Always the tasks list, never a pop — this screen is
                  // reached by pushing from Success, and popping would only
                  // land back there.
                  onPressed: () => context.go('/tasks'),
                ),
              ],
              // 1i puts the outcome chip inside the ink, not on the paper.
              bottom: Padding(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusChip(
                    status: a.effectiveStatus,
                    wasExtended: a.wasExtended,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 34),
                children: [
                  _Label(t.historyDetailChecklist(a.doneCount, a.items.length)),
                  for (final item in a.items) _ItemRow(item: item),
                  _Label(t.signatureTitle),
                  _Signature(assignment: a, locale: locale),
                  if (a.reviewNote != null && a.reviewNote!.isNotEmpty) ...[
                    _Label(t.historyDetailReviewer),
                    _ReviewerCard(note: a.reviewNote!),
                  ],
                  // What the staff member wrote at submit (submit_note).
                  if (a.submitNote?.trim().isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 14, 26, 0),
                      child: Text(
                        t.historyStaffNote(a.submitNote!.trim()),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: Color(0x99201E1D), // text @ 60%
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 12),
    child: Text(text.toUpperCase(), style: kSectionLabel),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final AssignmentItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final flagged = item.isFollowUp;
    // A glyph, not a checkbox — nothing here is toggleable any more. One per
    // outcome: a place a partial submit left unanswered gets a dash, where it
    // used to share the done check and claim work that was never sent.
    final (icon, ink) = switch (item.status) {
      'done' => (Icons.check, AppColors.cyanDark),
      'rejected' => (Icons.close, AppColors.magenta),
      'follow_up' => (Icons.flag_outlined, AppColors.magenta),
      _ => (Icons.remove, const Color(0x66201E1D)), // text @ 40%
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x14201E1D)), // text @ 8%
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: ink,
            semanticLabel: flagged ? t.followUpNeeded : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickLocalized(context, item.textAr, item.textEn),
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
                // What was answered, as sent. A flagged one in magenta, like
                // its flag — it is the answer that missed.
                if (item.answer != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    formatAnswer(context, item.answer!),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      color: flagged
                          ? AppColors.magenta
                          : const Color(0x99201E1D), // text @ 60%
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final path in item.photoPaths) ...[
            const SizedBox(width: 8),
            if (isVideoPath(path))
              // A clip plays full screen; a photo is its own thumbnail.
              Consumer(
                builder: (context, ref, _) => InkWell(
                  onTap: () => openEvidenceVideo(
                    context,
                    ref,
                    assignmentId: item.assignmentId,
                    path: path,
                  ),
                  child: PhotoThumb(
                    assignmentId: item.assignmentId,
                    path: path,
                    size: 44,
                  ),
                ),
              )
            else
              PhotoThumb(assignmentId: item.assignmentId, path: path, size: 42),
          ],
        ],
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature({required this.assignment, required this.locale});
  final Assignment assignment;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final signedAt = assignment.submittedAt ?? assignment.completedAt;
    final caption = [
      if (assignment.assigneeName.isNotEmpty) assignment.assigneeName,
      if (signedAt != null)
        DateFormat('d MMM y, HH:mm', locale).format(signedAt),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: kRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (assignment.signatureUrl != null)
            Positioned.fill(
              // The stroke is a drawing; it must not mirror in Arabic.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PhotoThumb(
                  assignmentId: assignment.id,
                  path: assignment.signatureUrl!,
                  size: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (caption.isNotEmpty)
            PositionedDirectional(
              start: 14,
              bottom: 8,
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0x73201E1D), // text @ 45%
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewerCard extends StatelessWidget {
  const _ReviewerCard({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 26),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cyanTint,
      borderRadius: kRadius,
    ),
    child: Text(
      note,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: AppColors.cyanDark,
      ),
    ),
  );
}
