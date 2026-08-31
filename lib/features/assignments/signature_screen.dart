import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// §5: the canvas is a drawing surface, not text — it must NOT mirror in
/// RTL, so it's wrapped in an explicit LTR Directionality regardless of
/// the app's current locale.
class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.isEmpty) return;
    setState(() => _submitting = true);
    final bytes = await _controller.toPngBytes();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sig_${widget.assignmentId}.png');
    await file.writeAsBytes(bytes!);

    await ref
        .read(assignmentsRepoProvider)
        .submit(widget.assignmentId, file.path);
    ref.invalidate(myAssignmentsProvider);
    if (mounted) context.go('/tasks/${widget.assignmentId}/success');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(t.signatureTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile != null)
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            Text(
              DateTime.now().toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _controller.clear,
                    child: Text(t.signatureClear),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.signatureSubmit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
