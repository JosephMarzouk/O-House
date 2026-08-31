import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Six statuses (§6/§13) plus an independent "extended" marker that can
/// sit alongside any of them — extension never changes effective_status
/// away from what it would otherwise be once un-expired.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.wasExtended = false});
  final String
  status; // pending|in_progress|submitted|approved|rejected|expired
  final bool wasExtended;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      'pending' => (t.statusPending, Colors.grey),
      'in_progress' => (t.statusInProgress, Colors.blue),
      'submitted' => (t.statusSubmitted, Colors.orange),
      'approved' => (t.statusApproved, Colors.green),
      'rejected' => (t.statusRejected, Colors.red),
      'expired' => (t.statusExpired, Colors.red.shade900),
      _ => (status, Colors.grey),
    };

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: color.withValues(alpha: 0.15),
          labelStyle: TextStyle(color: color),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        if (wasExtended)
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.amber.shade800,
          ),
      ],
    );
  }
}
