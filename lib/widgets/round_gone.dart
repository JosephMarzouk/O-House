import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// FIELD-08 / F-44: a round that isn't on this phone. While the list is still
/// loading (a push for a new round refreshes it) that is a spinner; once it
/// has loaded and the round isn't there (someone else claimed it, the planner
/// removed or moved it), it says so with a way back, never an endless spinner.
/// Work already queued for it parks with its reason (sync_banner.dart).
class RoundGone extends ConsumerWidget {
  const RoundGone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myAssignmentsProvider);
    if (!list.hasValue || list.isLoading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.roundGoneTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(t.roundGoneBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/tasks'),
              child: Text(t.roundGoneBack),
            ),
          ],
        ),
      ),
    );
  }
}
