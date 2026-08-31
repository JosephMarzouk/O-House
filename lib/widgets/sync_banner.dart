import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';

/// Shown under the app bar whenever the outbox is non-empty (§6, §7C).
/// Always empty in Phase 1 (online-only) — starts doing real work once
/// Phase 3 wires offline writes.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(outboxCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final t = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        t.homeOfflineBanner(count),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
