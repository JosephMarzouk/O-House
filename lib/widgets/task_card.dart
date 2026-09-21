import 'package:flutter/material.dart';

import '../l10n/localized_text.dart';
import '../models/assignment.dart';
import '../theme.dart';
import 'status_chip.dart';
import 'task_progress_bar.dart';

/// One row of the Tasks list (artboard 1c). Lives here rather than inside
/// list_screen.dart because all three tabs render it, and the Today tab shows
/// every status — so the card has to carry the tag and the progress bar itself
/// rather than leaving each tab to assemble them.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.assignment, required this.onTap});
  final Assignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
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
