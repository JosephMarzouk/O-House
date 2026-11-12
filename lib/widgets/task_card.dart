import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_text.dart';
import '../models/assignment.dart';
import '../theme.dart';
import 'status_chip.dart';
import 'task_progress_bar.dart';

/// One row of the Tasks list (artboard 1c). Lives here rather than inside
/// list_screen.dart because all three tabs render it, and the Today tab shows
/// every status — so the card has to carry the tag and the progress bar itself
/// rather than leaving each tab to assemble them.
class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.assignment,
    required this.onTap,
    this.showRound = true,
  });
  final Assignment assignment;
  final VoidCallback onTap;

  /// Off on a task's own places screen, whose header already names the
  /// round: the same kicker on every card there is only noise.
  final bool showRound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = assignment;
    final now = ref.watch(serverClockProvider)();
    final notOpen = a.isNotOpenAt(now);
    final round = showRound
        ? pickLocalized(context, a.roundTitleAr, a.roundTitleEn)
        : '';
    final title = pickLocalized(context, a.titleAr, a.titleEn);
    final site = pickLocalized(context, a.siteNameAr, a.siteNameEn);
    final window = formatWindow(a.windowStart, a.windowEnd);
    const meta = TextStyle(
      fontSize: 13.5,
      height: 1.2,
      color: Color(0x99201E1D), // text @ 60%
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadiusFloating,
        boxShadow: [kShadowMd],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: kRadiusFloating,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The round as a kicker over the place. Each card is one
                // place, and the list deliberately does not group by round,
                // so this is what lets a round's places read as one set.
                if (round.isNotEmpty) ...[
                  Text(
                    round.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kSectionLabel,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusChip(
                      status: a.effectiveStatus,
                      wasExtended: a.wasExtended,
                    ),
                  ],
                ),
                if (site.isNotEmpty || window != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (site.isNotEmpty) ...[
                        const Icon(
                          Icons.place_outlined,
                          size: 17,
                          color: Color(0x99201E1D),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            site,
                            style: meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (site.isNotEmpty && window != null)
                        const Text('  ·  ', style: meta),
                      if (window != null) ...[
                        const Icon(
                          Icons.schedule,
                          size: 17,
                          color: Color(0x99201E1D),
                        ),
                        const SizedBox(width: 5),
                        Text(window, style: meta),
                      ],
                    ],
                  ),
                ],
                // A multi-day task: the window is each day's, so say when
                // the task itself ends.
                if (a.endDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 17,
                        color: Color(0x99201E1D),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppLocalizations.of(context)!.untilDate(
                          DateFormat(
                            'EEE d MMM',
                            Localizations.localeOf(context).toString(),
                          ).format(a.endDate!),
                        ),
                        style: meta,
                      ),
                    ],
                  ),
                ],
                // Waiting for its place's QR (never on a checklist without
                // the switch, so single places look exactly as before).
                // Before its time "Opens at 09:55" says more than "Locked":
                // not even a scan opens it yet.
                if (notOpen) ...[
                  const SizedBox(height: 8),
                  _Badge(
                    icon: Icons.schedule,
                    label: opensAtText(context, a, now),
                  ),
                ] else if (a.isLocked) ...[
                  const SizedBox(height: 8),
                  _Badge(
                    icon: Icons.lock_outline,
                    label: AppLocalizations.of(context)!.qrLocked,
                  ),
                ],
                if (a.reviewNote != null && a.reviewNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    a.reviewNote!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.magenta,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TaskProgressBar(
                  done: a.doneCount,
                  total: a.items.length,
                  fill: TaskProgressBar.fillFor(a.effectiveStatus),
                  showLabel: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One card for a task over several places (QA, QK): the task's name, how
/// many places are done and how many still wait for their QR. The places
/// themselves are on /groups/:id. [places] are the task's checklists on this
/// phone in this tab; the counts are of those.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.places, required this.onTap});
  final List<Assignment> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final done = places.where((a) => a.isSent).length;
    final locked = places.where((a) => a.isLocked).length;
    const meta = TextStyle(
      fontSize: 13.5,
      height: 1.2,
      color: Color(0x99201E1D), // text @ 60%
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadiusFloating,
        boxShadow: [kShadowMd],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: kRadiusFloating,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupTitle(context, places.first),
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // A Wrap, not a Row: in Arabic both phrases are longer, and
                // the second may need its own line on a narrow phone.
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 17,
                          color: Color(0x99201E1D),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            t.groupPlacesDone(done, places.length),
                            style: meta,
                          ),
                        ),
                      ],
                    ),
                    if (locked > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 17,
                            color: AppColors.cyanDark,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              t.groupLockedCount(locked),
                              style: meta.copyWith(color: AppColors.cyanDark),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TaskProgressBar(done: done, total: places.length),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Locked" (the checklist waits for its place's QR) or "Opens at 09:55" (its
/// time hasn't come). cyanDark, not magenta: both are the normal start of a
/// place, not an alarm.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.cyanDark),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.cyanDark,
        ),
      ),
    ],
  );
}
