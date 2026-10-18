import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:signature/signature.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_snack.dart';
import '../../widgets/sync_banner.dart';
import '../home/home_header.dart';

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
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _doSubmit();
    } catch (e, s) {
      // Same trap as the detail screen's: writing the PNG and enqueueing both
      // touch the filesystem, and an unguarded throw here left the button
      // spinning with the reason invisible.
      debugPrint('[submit] signature failed: $e\n$s');
      if (mounted) {
        setState(() => _submitting = false);
        showErrorSnack(context, 'Could not submit: $e');
      }
    }
  }

  Future<void> _editNote() async {
    final t = AppLocalizations.of(context)!;
    final draft = TextEditingController(text: _note.text);
    final saved = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.signatureNoteLabel),
        content: TextField(
          controller: draft,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, draft.text),
            child: Text(t.commonSave),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's TextField still reads it while the
    // route animates closed. Nothing listens to it afterwards, so it is
    // simply collected.
    if (saved != null && mounted) setState(() => _note.text = saved);
  }

  Future<void> _doSubmit() async {
    final repo = ref.read(assignmentsRepoProvider)!;
    final png = await _controller.toPngBytes();
    // Written into the evidence folder under a signature id fixed now, and
    // queued. At most one pending submit per round (SY-4): signing again
    // after backing out does not queue a second.
    await repo.submit(widget.assignmentId, png!, note: _note.text);

    // Try to send it now, but never make anyone wait on a bad connection:
    // after a few seconds the round is honestly "saved on this phone" and the
    // outbox carries on by itself (reconnect, resume, backoff).
    final sync = ref.read(syncServiceProvider);
    try {
      await sync?.drain().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Still sending; the success screen says it is saved, not sent.
    }

    // Refused? Then it is parked and the person must see why, not a success
    // screen. The banner on Home lists it with Retry and Dismiss.
    final parked = await repo.parkedCode(widget.assignmentId);
    if (parked != null) {
      if (!mounted) return;
      showErrorSnack(context, refusalReason(AppLocalizations.of(context)!, parked));
      context.go('/home');
      return;
    }

    // Sent: the drain's onSent already asked for a refresh, and the success
    // screen picks its face from the server's verdict (submitted or
    // follow_up), so wait for it. Offline this fails fast and the queued
    // face shows instead.
    try {
      await ref.read(roundsRefreshProvider.future);
    } catch (e) {
      debugPrint('[submit] re-read after drain failed: $e');
    }
    if (mounted) context.go('/tasks/${widget.assignmentId}/success');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    // Who is signing and when, in the header rather than stacked above the pad
    // — it is the same identity line every other screen carries.
    final signer = [
      ?roleLabel(context, profile),
      DateFormat(
        'd MMM y, HH:mm',
        Localizations.localeOf(context).toString(),
      ).format(DateTime.now()),
    ].join(' · ');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            AppHeader(
              title: profile?.name ?? t.signatureTitle,
              subtitle: signer,
              actions: [
                // The optional note for the supervisor, behind an icon so the
                // pad keeps its size. Filled once something is written.
                HeaderIconButton(
                  icon: _note.text.trim().isEmpty
                      ? Icons.sticky_note_2_outlined
                      : Icons.sticky_note_2,
                  label: t.signatureNoteLabel,
                  onPressed: _editNote,
                ),
                HeaderIconButton(
                  icon: Icons.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/tasks'),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.signatureTitle, style: kSectionLabel),
                    const SizedBox(height: 10),
                    // Capped rather than free-growing: the pad used to take
                    // every leftover pixel, which on a tall phone made a
                    // signature box deeper than the screen it sits on. And
                    // it shrinks below the cap: a fixed 420 pushed Submit off
                    // a 360x640 screen (B20); the buttons always fit now.
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: SizedBox.expand(
                            child: Directionality(
                              // A drawing surface, not text — it must not mirror.
                              textDirection: TextDirection.ltr,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.divider),
                                  borderRadius: kRadius,
                                ),
                                child: Signature(
                                  controller: _controller,
                                  backgroundColor: AppColors.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(t.signatureSubmit),
                          ),
                        ),
                      ],
                    ),
                    // Above the system navigation bar (3-button or gesture).
                    SizedBox(height: 26 + MediaQuery.viewPaddingOf(context).bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
