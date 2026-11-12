import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/assignment.dart';
import '../../tenant.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_snack.dart';

/// QR-locked places (plan "QR-locked places on multi-place tasks").
///
/// A place's sticker reads `clubops:<clubSlug>:<code>`, printed by the
/// portal. The phone never holds the codes: each locked checklist carries
/// only `qr_hash`, the sha256 of its place's code, so a scan is checked here,
/// offline (Q5), and the server checks the code itself again when the queued
/// `scan` op lands. Enforcement is the app's alone (Q10): the server logs a
/// bad code but never refuses answers over it.

/// The view's `encode(digest(qr_code, 'sha256'), 'hex')`: lowercase hex of
/// the code's UTF-8 bytes. Pure, unit-tested against a known digest.
String qrHashOf(String code) => sha256.convert(utf8.encode(code)).toString();

enum QrVerdict {
  /// Another club's sticker: the slug is not this app's club.
  wrongClub,

  /// Not a place sticker at all, or none of the candidates' places.
  notInTask,

  /// [QrMatch.place] is the checklist the sticker opens.
  match,

  /// The sticker is right, but none of its checklists is open yet
  /// (Assignment.isNotOpenAt): [QrMatch.place] is the one that opens first.
  /// Nothing is queued, so the server never records or claims it early.
  notOpenYet,
}

typedef QrMatch = ({QrVerdict verdict, Assignment? place, String? code});

/// What a scanned [raw] payload opens among [candidates]: the checklists in
/// reach (the task's places when scanning from a task, else today's).
///
/// Only checklists that can still be filled and carry a hash take part. When
/// one place appears twice (a morning and an evening checklist of the same
/// pool, one sticker), only those whose time has come at [now] count; among
/// them a locked one wins over one already open, then the earlier in walk
/// order: the scan is for the work still waiting. A sticker that matches only
/// open checklists still "matches", so scanning twice just opens the place
/// rather than calling the right sticker wrong. A sticker whose checklists
/// are all still to come is [QrVerdict.notOpenYet], with the earliest.
///
/// Pure, unit-tested.
QrMatch matchQr(
  String raw, {
  required String clubSlug,
  required List<Assignment> candidates,
  required DateTime now,
}) {
  const none = (verdict: QrVerdict.notInTask, place: null, code: null);
  final parts = raw.trim().split(':');
  if (parts.length != 3 || parts[0] != 'clubops') return none;
  final slug = parts[1];
  final code = parts[2];
  if (slug.isEmpty || code.isEmpty) return none;
  if (slug != clubSlug) {
    return (verdict: QrVerdict.wrongClub, place: null, code: null);
  }
  final hash = qrHashOf(code);
  final hits = walkOrder([
    for (final a in candidates)
      if (!a.isReadOnly && a.qrRequired && a.qrHash == hash) a,
  ]);
  if (hits.isEmpty) return none;
  final open = [for (final a in hits) if (!a.isNotOpenAt(now)) a];
  if (open.isEmpty) {
    final first = hits.reduce(
      (x, y) => (y.openTime ?? now).isBefore(x.openTime ?? now) ? y : x,
    );
    return (verdict: QrVerdict.notOpenYet, place: first, code: null);
  }
  final place = open.firstWhere((a) => a.isLocked, orElse: () => open.first);
  return (verdict: QrVerdict.match, place: place, code: code);
}

/// A task's places in walk order: by the admin's position (none last), then
/// window start (none last), then in the order they came in. The position
/// comes first because a one-off task's places often share one window and
/// were all created in the same instant, so nothing else keeps the order the
/// admin set. Walk order is only shown (QF): places unlock in any order. A
/// stable sort by hand, since List.sort is not stable. Pure.
List<Assignment> walkOrder(List<Assignment> places) {
  final indexed = places.indexed.toList()
    ..sort((x, y) {
      final p = x.$2.groupPosition;
      final q = y.$2.groupPosition;
      if (p != q) {
        if (p == null) return 1;
        if (q == null) return -1;
        return p.compareTo(q);
      }
      final a = x.$2.windowStart;
      final b = y.$2.windowStart;
      if (a != b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      }
      return x.$1.compareTo(y.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// The checklists a scan can open: the task's places when [groupId] is set,
/// else everything of today's on this phone.
List<Assignment> scanCandidates(List<Assignment> all, String? groupId) => [
  for (final a in all)
    if (groupId != null ? a.groupId == groupId : a.isToday) a,
];

/// Opens the scanner and, on a match, the matched checklist. [fromId] is the
/// checklist the scan started on, if any: a match on it just unlocks it in
/// place; a match on another place replaces it, so Back still leads to the
/// task rather than through every place scanned on the way.
Future<void> scanPlace(
  BuildContext context, {
  String? groupId,
  String? fromId,
}) async {
  final query = groupId == null ? '' : '?group=${Uri.encodeQueryComponent(groupId)}';
  final id = await context.push<String>('/scan$query');
  if (id == null || id == fromId || !context.mounted) return;
  fromId == null
      ? unawaited(context.push('/tasks/$id'))
      : context.pushReplacement('/tasks/$id');
}

/// `/scan`: the camera, looking for a place's sticker. Pops with the matched
/// checklist's id once its scan is queued (a place already open just pops),
/// stays open with the reason on any other QR.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.groupId});

  /// Scanning from a task: only its places match.
  final String? groupId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    // The same sticker held in view fires once, not every frame.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    String? raw;
    for (final b in capture.barcodes) {
      raw ??= b.rawValue;
    }
    if (raw == null) return;
    final t = AppLocalizations.of(context)!;
    final all = ref.read(myAssignmentsProvider).valueOrNull ?? const [];
    final now = ref.read(serverClockProvider)();
    final r = matchQr(
      raw,
      clubSlug: tenant.clubSlug,
      candidates: scanCandidates(all, widget.groupId),
      now: now,
    );
    switch (r.verdict) {
      case QrVerdict.wrongClub:
        setState(() => _message = t.qrWrongClub);
      case QrVerdict.notInTask:
        setState(() => _message = t.qrNotInTask);
      case QrVerdict.notOpenYet:
        setState(() => _message = opensAtText(context, r.place!, now));
      case QrVerdict.match:
        _busy = true;
        await _unlock(r.place!, r.code!);
    }
  }

  Future<void> _unlock(Assignment place, String code) async {
    if (place.isLocked) {
      final repo = ref.read(assignmentsRepoProvider);
      try {
        await repo?.queueScan(place.id, code);
      } catch (e) {
        // sqflite failed: nothing queued, so the place stays shut and says why.
        debugPrint('[scan] queueing failed: $e');
        if (mounted) showErrorSnack(context, 'Could not save this scan: $e');
        _busy = false;
        return;
      }
      unawaited(HapticFeedback.mediumImpact());
      // Re-read before leaving, so the checklist opens unlocked rather than
      // flashing its lock for a frame.
      ref.invalidate(myAssignmentsProvider);
      try {
        await ref.read(myAssignmentsProvider.future);
      } catch (_) {}
      unawaited(ref.read(syncServiceProvider)?.drain());
    }
    if (mounted) context.pop(place.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            AppHeader(
              title: t.qrScanTitle,
              actions: [
                HeaderIconButton(
                  icon: Icons.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: MobileScanner(
                  controller: _camera,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraProblem(
                    refused:
                        error.errorCode ==
                        MobileScannerErrorCode.permissionDenied,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                  child: Row(
                    children: [
                      Icon(
                        _message == null
                            ? Icons.qr_code_scanner
                            : Icons.error_outline,
                        color: AppColors.cyanDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message ?? t.qrScanHint,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: _message == null
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// F-13's camera pattern, for the scanner: a refused camera says why, with
/// Open settings for when Android won't ask any more; any other camera error
/// says so too, never a black box.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.refused});
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ColoredBox(
      color: AppColors.paper,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 40,
                color: AppColors.cyanDark,
              ),
              const SizedBox(height: 16),
              if (refused) ...[
                Text(
                  t.cameraAccessTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                refused ? t.qrCameraReason : t.cameraUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              if (refused) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: Geolocator.openAppSettings,
                  child: Text(t.zoneOpenSettings),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
