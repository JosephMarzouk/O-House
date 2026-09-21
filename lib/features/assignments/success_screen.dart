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
class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final a = ref.watch(assignmentByIdProvider(assignmentId));
    final locale = Localizations.localeOf(context).toString();

    String? detail;
    if (a != null) {
      final title = pickLocalized(context, a.titleAr, a.titleEn);
      final site = pickLocalized(context, a.siteNameAr, a.siteNameEn);
      // submitted_at is filled in by the server, so it is still null here on
      // the hop straight from the signature pad.
      final at = DateFormat.Hm(locale).format(a.submittedAt ?? DateTime.now());
      detail = t.successDetail(site.isEmpty ? title : '$title — $site', at);
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
                    const Icon(
                      Icons.verified_rounded,
                      size: 104,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      t.successTitle,
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
                  FilledButton(
                    onPressed: () => context.go('/tasks'),
                    child: Text(t.successBackButton),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => context.push('/history/$assignmentId'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cyan,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(t.successViewSubmission),
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
