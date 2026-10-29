import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/local_db.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_text.dart';
import '../tenant.dart';
import '../theme.dart';

/// SY-5: offline (n waiting, last updated), sending (n of m), needs
/// attention, can't reach the server. Hidden when everything is sent and the
/// last fetch worked. "Needs attention" wins over the rest, because it is the
/// one state a person has to act on; a tap opens the parked list.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final s = ref.watch(syncStatusProvider);
    final failed = ref.watch(refreshFailedProvider);

    final String text;
    var alarm = false;
    if (s.parked > 0) {
      text = t.syncNeedsAttention(s.parked);
      alarm = true;
    } else if (s.sending && s.total > 0) {
      text = t.syncSending(s.sent, s.total);
    } else if (failed) {
      // The last fetch failed, whatever the outbox holds: with nothing to
      // send, a phone that could not reach the API once looked online for a
      // day while showing old tasks. A dev build names the API it tried, so
      // a missing `adb reverse` is plain to see.
      final at = ref.watch(refreshedAtProvider).valueOrNull;
      text = [
        t.syncServerUnreachable,
        if (at != null)
          t.syncLastUpdated(
            DateFormat.Hm(Localizations.localeOf(context).toString()).format(at),
          ),
        if (s.waiting > 0) t.homeOfflineBanner(s.waiting),
        if (environment == 'dev') Uri.parse(apiBaseUrl).authority,
      ].join(' · ');
    } else if (s.offline) {
      final at = ref.watch(refreshedAtProvider).valueOrNull;
      text = [
        if (s.waiting > 0) t.homeOfflineBanner(s.waiting),
        if (at != null)
          t.syncOfflineUpdated(
            DateFormat.Hm(Localizations.localeOf(context).toString()).format(at),
          ),
      ].join(' · ');
    } else if (s.waiting > 0) {
      text = t.homeOfflineBanner(s.waiting);
    } else {
      return const SizedBox.shrink();
    }
    if (text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: alarm ? AppColors.magentaTint : Colors.amber.shade100,
      child: InkWell(
        onTap: alarm ? () => showParkedSheet(context) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: alarm ? AppColors.magentaDeep : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// The reason a refusal happened, in the person's language (SY-6).
String refusalReason(AppLocalizations t, String code) => switch (code) {
  'ASSIGNMENT_EXPIRED' => t.refusalExpired,
  'ASSIGNMENT_CLOSED' => t.refusalClosed,
  'ASSIGNMENT_NOT_FOUND' || 'ITEM_NOT_FOUND' => t.refusalNotFound,
  'NOT_AUTHORIZED' => t.refusalNotAuthorized,
  'ASSIGNMENT_TAKEN' => t.refusalTaken,
  'MISSING_PHOTO' => t.refusalMissingPhoto,
  'EMPTY_SUBMISSION' => t.refusalEmpty,
  'MISSING_FILE' => t.refusalMissingFile,
  'STILL_FAILING' => t.refusalStillFailing,
  'NO_ACCESS' => t.refusalNoAccess,
  _ => t.refusalOther,
};

Future<void> showParkedSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ParkedSheet(),
    );

class _ParkedSheet extends ConsumerWidget {
  const _ParkedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final ops = ref.watch(parkedOpsProvider).valueOrNull ?? const [];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          children: [
            Text(t.parkedTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            for (final op in ops) _ParkedRow(op: op),
          ],
        ),
      ),
    );
  }
}

class _ParkedRow extends ConsumerWidget {
  const _ParkedRow({required this.op});
  final OutboxOp op;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final a = ref.watch(assignmentByIdProvider(op.assignmentId));
    final what = switch (op.op) {
      'photo' => t.parkedOpPhoto,
      'submit' => t.parkedOpSubmit,
      'scan' => t.parkedOpScan,
      _ => t.parkedOpAnswer,
    };
    final round = a == null ? '' : pickLocalized(context, a.titleAr, a.titleEn);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadius,
        boxShadow: [kShadowMd],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            round.isEmpty ? what : '$what · $round',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            refusalReason(t, op.parkedCode ?? ''),
            style: const TextStyle(fontSize: 13.5, color: AppColors.magentaDeep),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _dismiss(context, ref),
                  child: Text(t.parkedDismiss),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref.read(syncServiceProvider)?.retry(op.id),
                  child: Text(t.commonRetry),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dismissing throws work away, so it asks first. Nothing is ever deleted
  /// without a person seeing it (plan, refusal contract).
  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(t.parkedDismissConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.parkedDismiss),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(syncServiceProvider)?.dismiss(op);
  }
}
