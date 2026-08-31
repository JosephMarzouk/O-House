import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/photo_thumb.dart';
import '../../widgets/status_chip.dart';

/// §6, screen 10 — fully read-only, no item sheet, no submit bar.
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final assignment = ref.watch(assignmentByIdProvider(assignmentId));

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.historyDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  assignment.titleEn,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusChip(
                status: assignment.effectiveStatus,
                wasExtended: assignment.wasExtended,
              ),
            ],
          ),
          if (assignment.wasExtended && assignment.extensionNote != null) ...[
            const SizedBox(height: 8),
            Text(
              '⚠ ${assignment.extensionNote}',
              style: const TextStyle(color: Colors.amber),
            ),
          ],
          const SizedBox(height: 16),
          ...assignment.items.map(
            (item) => ListTile(
              leading: Icon(
                item.status == 'rejected'
                    ? Icons.error_outline
                    : item.status == 'done'
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: item.status == 'rejected'
                    ? Colors.red
                    : (item.status == 'done' ? Colors.green : null),
              ),
              title: Text(item.textEn),
              subtitle: item.photoPaths.isEmpty
                  ? null
                  : Wrap(
                      spacing: 6,
                      children: item.photoPaths
                          .map((p) => PhotoThumb(path: p, size: 40))
                          .toList(),
                    ),
            ),
          ),
          if (assignment.reviewNote != null) ...[
            const Divider(height: 32),
            Text(t.historyDetailReviewNote(assignment.reviewNote!)),
          ],
          if (assignment.signatureUrl != null) ...[
            const Divider(height: 32),
            Text(
              t.signatureTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: PhotoThumb(path: assignment.signatureUrl!, size: 160),
            ),
          ],
        ],
      ),
    );
  }
}
