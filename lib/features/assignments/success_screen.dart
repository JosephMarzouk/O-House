import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../theme.dart';

/// §6, screen 9 — artboard 1h. The hero sits centred in whatever space is
/// left; the two buttons are pinned to the bottom.
///
/// It takes the assignment id so it can name what was just sent — a success
/// screen that cannot tell you *which* round it submitted is not confirming
/// much.
///
/// It has a second face for a round that came back in follow_up: sent, but
/// with at least one answer that missed its item's rule, so the round waits
/// on this person rather than on a supervisor (0013). "Submitted for review"
/// would be false there, so that face says how many answers did not match
/// and leads back into the round. It relies on the signature screen having
/// re-read the round before navigating here — the status only exists once
/// the server has judged the answers.
class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final a = ref.watch(assignmentByIdProvider(assignmentId));
    final locale = Localizations.localeOf(context).toString();
    // Still in the outbox: saved, not sent. Saying "submitted" here was the
    // lie that hid unsent rounds; this face says what is true.
    final queued =
        ref.watch(pendingRoundsProvider).valueOrNull?.contains(assignmentId) ??
        false;

    final Widget hero;
    final String title;
    String? detail;
    final (String, VoidCallback) primary;
    final (String, VoidCallback) secondary;

    if (a != null && a.effectiveStatus == 'follow_up') {
      hero = Container(
        width: 104,
        height: 104,
        decoration: const BoxDecoration(
          color: AppColors.magentaTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.flag_outlined,
          size: 52,
          color: AppColors.magenta,
        ),
      );
      title = t.successFollowUpTitle;
      detail = t.successFollowUpBody(a.items.where((i) => i.isFollowUp).length);
      // go, not push: a pushed round would pop straight back onto this
      // screen — the trap HistoryDetailScreen's close button documents.
      primary = (
        t.successReviewFlagged,
        () => context.go('/tasks/$assignmentId'),
      );
      secondary = (t.successBackButton, () => context.go('/tasks'));
    } else {
      hero = Icon(
        Icons.verified_rounded,
        size: 104,
        color: AppColors.cyan,
      );
      title = queued ? t.successQueuedTitle : t.successTitle;
      if (a != null) {
        final name = pickLocalized(context, a.titleAr, a.titleEn);
        final site = pickLocalized(context, a.siteNameAr, a.siteNameEn);
        final task = site.isEmpty ? name : '$name — $site';
        // submitted_at is filled in by the server, so it is still null here
        // on the hop straight from the signature pad.
        final at = DateFormat.Hm(locale)
            .format(a.submittedAt ?? DateTime.now());
        detail = queued
            ? t.successQueuedBody(task)
            : t.successDetail(task, at);
      }
      primary = (t.successBackButton, () => context.go('/tasks'));
      secondary = (
        t.successViewSubmission,
        () => context.push('/history/$assignmentId'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    hero,
                    const SizedBox(height: 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6, // -.02em
                        color: AppColors.text,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0x99201E1D), // text @ 60%
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(onPressed: primary.$2, child: Text(primary.$1)),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: secondary.$2,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cyanDark,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(secondary.$1),
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
