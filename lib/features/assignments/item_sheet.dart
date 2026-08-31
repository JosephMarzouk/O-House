import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assignment_item.dart';
import '../../widgets/photo_thumb.dart';

/// §6, screen 7 — a bottom sheet, not a route, so the checklist stays
/// visible behind it.
Future<void> showItemSheet(
  BuildContext context,
  WidgetRef ref, {
  required String assignmentId,
  required AssignmentItem item,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ItemSheet(assignmentId: assignmentId, item: item),
  );
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.assignmentId, required this.item});
  final String assignmentId;
  final AssignmentItem item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  final _note = TextEditingController();
  final _photos = <String>[];
  bool _saving = false;

  Future<void> _takePhoto() async {
    // Camera only, never the gallery — a photo from the gallery isn't
    // evidence of anything (§9). Compression lands in Phase 2.
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _photos.add(picked.path));
  }

  Future<void> _markDone(AppLocalizations t) async {
    setState(() => _saving = true);
    final repo = ref.read(assignmentsRepoProvider);
    for (final path in _photos) {
      await repo.attachItemPhoto(widget.assignmentId, widget.item.id, path);
    }
    await repo.markItemDone(
      widget.assignmentId,
      widget.item.id,
      note: _note.text.isEmpty ? null : _note.text,
    );
    ref.invalidate(myAssignmentsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final text = locale == 'ar' && widget.item.textAr.isNotEmpty
        ? widget.item.textAr
        : widget.item.textEn;
    final canFinish = !widget.item.requiresPhoto || _photos.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (widget.item.requiresPhoto) ...[
            const SizedBox(height: 4),
            Text(
              t.taskDetailPhotoRequired,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ..._photos.map((p) => PhotoThumb(path: p)),
              ...widget.item.photoPaths.map((p) => PhotoThumb(path: p)),
              OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(t.itemSheetTakePhoto),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: t.itemSheetNote,
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving || !canFinish ? null : () => _markDone(t),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.itemSheetMarkDone),
          ),
        ],
      ),
    );
  }
}
