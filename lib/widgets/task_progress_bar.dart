import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// How far through a round the user is. Owns the done/total arithmetic so the
/// task card and the detail header cannot disagree about it, and takes colours
/// rather than a status string — the same call the four _StatTile call sites on
/// Home make, for the same reason: the caller already knows which case it is.
///
/// Use [fillFor] to get the design's status-driven fill (artboard 1c: the bar
/// turns magenta on a rejected round and cyan-dark once it has been sent).
class TaskProgressBar extends StatelessWidget {
  const TaskProgressBar({
    super.key,
    required this.done,
    required this.total,
    this.fill = AppColors.cyan,
    this.track = const Color(0x1F201E1D), // text @ 12%
    this.height = 6,
    this.showLabel = false,
    this.labelColor = const Color(0xB3201E1D), // text @ 70%
  });

  final int done;
  final int total;
  final Color fill;
  final Color track;
  final double height;
  final bool showLabel;
  final Color labelColor;

  /// Track colour for a bar drawn on the ink header rather than on paper.
  static const onInkTrack = Color(0x33F3F2F2); // paper @ 20%

  static Color fillFor(String effectiveStatus) => switch (effectiveStatus) {
    'submitted' || 'approved' => AppColors.cyanDark,
    'rejected' => AppColors.magenta,
    _ => AppColors.cyan,
  };

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: track,
        // Directional so the bar fills from the right in Arabic.
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(color: fill)),
        ),
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 12),
        Text(
          t.tasksProgress(done, total),
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
