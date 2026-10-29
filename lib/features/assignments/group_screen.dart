import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/round_gone.dart';
import '../../widgets/task_card.dart';
import 'qr_scan.dart';

/// `/groups/:id`: one task over several places (a zone round or a one-off
/// multi-place task), opened from its card on Tasks or from its push (QG).
///
/// Each place is still its own checklist, opened, filled and submitted on its
/// own (QB); this screen only lists them in walk order with their status and
/// lock, plus Scan. A locked place opens too, in its locked state, so staff
/// can read what is waiting there before they walk over.
///
/// Top-level like /tasks/:id, so no nav bar and a back arrow; no navBarExtent
/// padding is owed for the same reason.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final all = ref.watch(myAssignmentsProvider).valueOrNull ?? const [];
    final places = walkOrder([
      for (final a in all)
        if (a.groupId == groupId) a,
    ]);
    // Claimed by someone else, or not on this phone yet: say so (FIELD-08).
    if (places.isEmpty) return const RoundGone();

    final first = places.first;
    final done = places.where((a) => a.isSent).length;
    final anyLocked = places.any((a) => a.isLocked);
    final locale = Localizations.localeOf(context).toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            AppHeader(
              title: groupTitle(context, first),
              subtitle: [
                t.groupPlacesDone(done, places.length),
                if (first.scheduledDate != null)
                  DateFormat('EEE d MMM', locale).format(first.scheduledDate!),
              ].join(' · '),
              actions: [
                HeaderIconButton(
                  icon: Icons.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  // A push straight to a task has nothing to pop back to.
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/tasks'),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => refreshRounds(ref),
                color: AppColors.cyan,
                backgroundColor: AppColors.paper,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  itemCount: places.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        t.groupPlacesLabel.toUpperCase(),
                        style: kSectionLabel,
                      );
                    }
                    final a = places[i - 1];
                    return TaskCard(
                      assignment: a,
                      showRound: false,
                      onTap: () => context.push('/tasks/${a.id}'),
                    );
                  },
                ),
              ),
            ),
            // Only while a place still waits for its QR: once all are open
            // there is nothing to scan.
            if (anyLocked)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: FilledButton.icon(
                      onPressed: () => scanPlace(context, groupId: groupId),
                      icon: const Icon(Icons.qr_code_scanner, size: 22),
                      label: Text(t.qrScanButton),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
