import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../data/fixtures.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_snack.dart';
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
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
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

  Future<void> _doSubmit() async {
    String path;
    if (kDemoData) {
      // path_provider has no web support, and the demo repo never uploads the
      // file anyway — writing it would only break the browser preview at the
      // last step of the flow.
      path = 'demo/sig_${widget.assignmentId}.png';
    } else {
      final bytes = await _controller.toPngBytes();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sig_${widget.assignmentId}.png');
      await file.writeAsBytes(bytes!);
      path = file.path;
    }

    await ref.read(assignmentsRepoProvider).submit(widget.assignmentId, path);

    // This line is the whole reason a submit reaches the server. Every repo
    // write only enqueues; SyncService.drain() is the only code that replays
    // the queue, and its one other trigger is a connectivity *change* — which
    // on a phone that is online and stays online never comes. Without this the
    // round sits in the outbox until the next cold start.
    //
    // Here specifically, because this is the only moment the outbox holds a
    // complete round in FIFO order: photos, then the ticks, then the submit.
    // And before the invalidate below, because that refetches from the server
    // — drain first and the refresh reads a server that has the work; refresh
    // first and it reads one that does not, which is what made the ticks
    // appear to revert.
    //
    // drain() swallows its own failures, so there is no new error path: offline
    // it stops at the first op and the round stays queued for reconnect.
    // ponytail: awaited, so Submit now blocks on the upload of uncompressed
    // photos — Phase 2 compression is what makes that acceptable on 3G.
    final sync = ref.read(syncServiceProvider);
    await sync.drain(watch: widget.assignmentId);

    // drain() never throws — it is a background replay — so its failure has to
    // be read, not caught. Showing the success screen on top of a queue that
    // stopped dead is the exact lie that made this bug invisible: the round
    // reads "Submitted for review" while the server has never heard of it.
    //
    // ponytail: this refuses to advance on ANY drain failure, including a
    // plain offline one where queueing is the correct outcome and success
    // would be honest. Splitting "queued, will send" from "rejected, will
    // never send" is the phase-4 work in sync.dart's TODO; until then, over-
    // reporting a problem beats under-reporting one.
    final error = sync.lastError;
    if (error != null) {
      if (mounted) {
        setState(() => _submitting = false);
        showErrorSnack(context, error);
      }
      return;
    }

    // Awaited, not a bare invalidate. The success screen picks its face from
    // this round's status, and only the server knows whether the answers
    // just sent put it in follow_up — an un-awaited refetch let it paint the
    // stale in_progress round first, then flip. Guarded, because the round
    // has already landed: a failed re-read is no reason to strand anyone on
    // the pad, and the success screen then falls back to the plain face.
    //
    // Spelled invalidate-then-read rather than `await ref.refresh(...)`,
    // which is exactly those two calls: refresh is @useResult, and awaiting
    // its future does not count as using it.
    try {
      ref.invalidate(myAssignmentsProvider);
      await ref.read(myAssignmentsProvider.future);
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
      ?roleLabel(profile),
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
                    // signature box deeper than the screen it sits on.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
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
                    const Spacer(),
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
                    const SizedBox(height: 26),
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
