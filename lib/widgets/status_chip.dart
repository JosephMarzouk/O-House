import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Seven statuses (§6/§13, plus 0013's follow_up) and an independent
/// "extended" marker that can sit alongside any of them — extension never
/// changes effective_status away from what it would otherwise be once
/// un-expired.
///
/// The four tag treatments come from artboard 1c of the design handoff: a
/// tinted tag for work in flight, solid grounds for the two closed states,
/// and an outline for overdue. Colours are palette-only — magenta is reserved
/// for the alarm states, rejected, overdue and follow-up, per AppColors' rule.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.wasExtended = false});
  final String
  status; // pending|in_progress|submitted|approved|rejected|expired|follow_up
  final bool wasExtended;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final (label, ground, ink, icon, border) = switch (status) {
      'pending' => (
        t.statusPending,
        AppColors.surface,
        const Color(0x99201E1D), // text @ 60%
        Icons.schedule,
        false,
      ),
      'in_progress' => (
        t.statusInProgress,
        AppColors.cyanTint,
        AppColors.cyanDark,
        Icons.more_horiz,
        false,
      ),
      'submitted' => (
        t.statusSubmitted,
        AppColors.cyanDark,
        AppColors.paper,
        Icons.send_rounded,
        false,
      ),
      'approved' => (
        t.statusApproved,
        AppColors.cyan,
        AppColors.onCyan,
        Icons.check_circle,
        false,
      ),
      'rejected' => (
        t.statusRejected,
        AppColors.magenta,
        AppColors.paper,
        Icons.cancel,
        false,
      ),
      'expired' => (
        t.statusExpired,
        Colors.transparent,
        AppColors.magenta,
        Icons.timer_off_outlined,
        true,
      ),
      // Tinted like in_progress, not solid like rejected: sent, but with
      // answers of this person's own to fix — work in flight, in alarm
      // colours. The same tint/deep pair the portal's follow-up tag uses.
      'follow_up' => (
        t.statusFollowUp,
        AppColors.magentaTint,
        AppColors.magentaDeep,
        Icons.flag_outlined,
        false,
      ),
      _ => (
        status,
        AppColors.surface,
        const Color(0x99201E1D),
        Icons.help_outline,
        false,
      ),
    };

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Tag(
          label: label,
          ground: ground,
          ink: ink,
          icon: icon,
          border: border,
        ),
        // Its own tag rather than a bare warning icon: "extended" is a fact
        // about the deadline, not an alarm, and amber is not in the palette.
        if (wasExtended)
          _Tag(
            label: t.statusExtended,
            ground: AppColors.surface,
            ink: const Color(0x99201E1D), // text @ 60%
            icon: Icons.update,
            border: false,
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.ground,
    required this.ink,
    required this.icon,
    required this.border,
  });
  final String label;
  final Color ground;
  final Color ink;
  final IconData icon;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: ground,
      borderRadius: kRadiusControl,
      border: border ? Border.all(color: ink) : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ink),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ],
    ),
  );
}
