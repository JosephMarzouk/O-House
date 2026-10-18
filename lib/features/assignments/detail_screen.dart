import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../data/assignments_repo.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/assignment.dart';
import '../../models/assignment_item.dart';
import '../../models/club_zone.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/error_snack.dart';
import '../../widgets/round_gone.dart';
import '../../widgets/subtask_tile.dart';
import '../../widgets/task_progress_bar.dart';
import 'club_zone.dart';

/// The wire form of a typed answer — what mark_item_done() receives as
/// p_answer. Pure, unit-tested.
///
/// A number arrives in whatever digits the keyboard produced — an Arabic
/// keyboard types ٢٫٥ — so both Arabic-Indic digit sets and the ٫ and ,
/// decimal separators fold to ASCII. answer_ok() folds the same set before
/// its own numeric compare (0013's translate()), so this is not what lets a
/// right answer pass. It is what makes the answer that is *stored* — and
/// quoted back in the flag note and on the dashboard — read the same
/// whichever keyboard typed it. Every other type is only trimmed: yes/no and
/// pass/fail are canonical already, and free text is matched without regard
/// to case server-side, where a comma is just a comma.
String normalizeAnswer(String type, String raw) {
  final s = raw.trim();
  if (type != 'number') return s;
  // In order: ٠-٩ Arabic-Indic; ۰-۹ Extended Arabic-Indic (Persian/Urdu
  // layouts); ٫ the Arabic decimal separator, or a comma, to a point.
  return String.fromCharCodes([
    for (final c in s.runes)
      if (c >= 0x0660 && c <= 0x0669)
        c - 0x0660 + 0x30
      else if (c >= 0x06F0 && c <= 0x06F9)
        c - 0x06F0 + 0x30
      else if (c == 0x066B || c == 0x2C)
        0x2E
      else
        c,
  ]);
}

/// A place counts as answered if it was already done on the server or has an
/// answer staged this session. Nothing is written until Submit & Sign, so the
/// staged map is the only place a fresh answer lives.
///
/// A follow_up item is deliberately NOT answered: its answer is on the server
/// but wrong, and it only counts again once it is re-answered here. The
/// progress count and the follow-up submit gate both depend on that.
bool isItemChecked(AssignmentItem i, Map<String, String> staged) =>
    i.status == 'done' || staged.containsKey(i.id);

List<String> itemPhotos(AssignmentItem i, Map<String, List<String>> staged) => [
  ...i.photoPaths,
  ...?staged[i.id],
];

/// Answered places that still owe a photo. Drives both the submit gate and the
/// caption under the disabled button.
///
/// A follow_up item owes its photo whether or not it is re-answered:
/// submit_assignment() counts done AND follow_up items as answered work
/// (0013), so leaving it out here would open the button onto a MISSING_PHOTO
/// the server raises every time. It normally has one already — its first
/// submit could not have gone without — so this only bites when that upload
/// was dropped.
int missingPhotoCount(
  Assignment a,
  Map<String, String> answers,
  Map<String, List<String>> newPhotos,
) => a.items
    .where(
      (i) =>
          (isItemChecked(i, answers) || i.isFollowUp) &&
          i.requiresPhoto &&
          itemPhotos(i, newPhotos).isEmpty,
    )
    .length;

/// Every place the user actually answered that requires a photo must have
/// one. Unanswered places are simply left not-done — they do not block
/// submission.
///
/// Deliberately not Assignment.canSubmit, which encodes the all-done rule.
///
/// submit_assignment() agrees with this gate as of 0006_partial_submit.sql —
/// it requires at least one answered item and evidence only from the items
/// claimed answered, not from every item on the round.
///
/// A follow_up round has been submitted once already, so the work sitting on
/// the server proves nothing new: resubmitting it takes at least one answer
/// staged this session. A partial fix is enough — correct one of three
/// flagged items and send it; the round stays in follow_up until none are
/// left (0013).
bool canSubmitStaged(
  Assignment a,
  Map<String, String> answers,
  Map<String, List<String>> newPhotos,
) {
  final anyAnswered = a.effectiveStatus == 'follow_up'
      ? a.items.any((i) => answers.containsKey(i.id))
      : a.items.any((i) => isItemChecked(i, answers));
  return anyAnswered && missingPhotoCount(a, answers, newPhotos) == 0;
}

/// F-13 / FIELD-Q1: every capture tap asks for the camera again while it
/// isn't allowed. CAMERA is declared in the manifest, so image_picker
/// requests it itself before opening the camera, and answers
/// `camera_access_denied` when staff say no. Then the reason and Open
/// settings, for when Android won't ask any more. Any other picker error
/// (no camera app, the camera blocked) says so too, never silence.
Future<XFile?> openCamera(BuildContext context, Future<XFile?> Function() open) async {
  try {
    return await open();
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    final t = AppLocalizations.of(context)!;
    if (e.code != 'camera_access_denied') {
      showErrorSnack(context, t.cameraUnavailable);
      return null;
    }
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.cameraAccessTitle),
        content: Text(t.cameraAccessReason),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.commonCancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Geolocator.openAppSettings();
            },
            child: Text(t.zoneOpenSettings),
          ),
        ],
      ),
    );
    return null;
  }
}

/// B10 / F-41: which capture was in flight when the camera opened. Android can
/// kill this app while its camera runs (low memory); image_picker then keeps
/// the photo for retrieveLostData(), but not which item it was for. This
/// record, kept in the settings table across the restart, says.
const pendingCaptureKey = 'pending_capture';

@visibleForTesting
String pendingCaptureJson(String roundId, String itemId, String ext) =>
    jsonEncode({'round': roundId, 'item': itemId, 'ext': ext});

/// The pending capture for [roundId], or null (none, another round's, junk).
@visibleForTesting
({String item, String ext})? pendingCaptureFor(String? json, String roundId) {
  if (json == null) return null;
  try {
    final j = jsonDecode(json);
    if (j is Map && j['round'] == roundId && j['item'] is String) {
      return (item: j['item'] as String, ext: j['ext'] == 'mp4' ? 'mp4' : 'jpg');
    }
  } on FormatException {
    // Junk: no capture to recover.
  }
  return null;
}

/// §6, screen 6 — artboard 1d. Read-only once effective_status is submitted/
/// approved/expired (Assignment.isReadOnly); an expired task shows the locked
/// message from §13 instead of the submit bar.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  /// itemId -> answer made this session, already normalized, not yet written
  /// anywhere. An unanswered item is absent — never mapped to ''.
  final Map<String, String> _answers = {};

  /// itemId -> the number/text field's controller. Here rather than in the
  /// tile: the list builds lazily, and a tile scrolled out of reach is
  /// disposed along with anything it owns.
  final Map<String, TextEditingController> _controllers = {};

  /// itemId -> evidence files captured on this round, named `{photoId}.jpg`
  /// (the id is fixed at capture; see AssignmentsRepo.keepPhoto).
  final Map<String, List<String>> _newPhotos = {};

  bool _submitting = false;

  /// The last look at where the phone is (club_zone.dart); null until the
  /// first one lands. Only used while a zone is cached and the round can
  /// still be filled; see _zoneGate.
  ZoneCheck? _zoneCheck;
  bool _zoneChecking = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// LS-2: what was staged here survives the app being killed or the phone
  /// dying mid-round. The photos are already safe in the evidence folder.
  Future<void> _restore() async {
    final repo = ref.read(assignmentsRepoProvider);
    if (repo == null) return;
    try {
      final d = await repo.draft(widget.assignmentId);
      final photos = {
        for (final e in d.photos.entries)
          e.key: [for (final id in e.value) await repo.photoPath(id)],
      };
      if (mounted && !d.isEmpty) {
        setState(() {
          _answers.addAll(d.answers);
          _newPhotos.addAll(photos);
        });
      }
    } catch (e) {
      debugPrint('[draft] restore failed: $e');
    }
    await _recoverLostCapture(repo);
  }

  /// B10: a photo or clip taken just before Android killed the app comes
  /// back here, onto the item it was for. Only for this round's capture:
  /// retrieveLostData() hands the file over once, so another round's capture
  /// is left for that round.
  Future<void> _recoverLostCapture(AssignmentsRepo repo) async {
    try {
      final pending = pendingCaptureFor(await repo.db.getSetting(pendingCaptureKey), widget.assignmentId);
      if (pending == null) return;
      final lost = await ImagePicker().retrieveLostData();
      await repo.db.deleteSetting(pendingCaptureKey);
      final file = lost.file;
      if (lost.isEmpty || file == null) return;
      final path = await repo.photoPath(await repo.keepPhoto(file.path, ext: pending.ext));
      if (!mounted) return;
      setState(() => _newPhotos.putIfAbsent(pending.item, () => []).add(path));
      _persist();
    } catch (e) {
      // No picker on this platform (tests, web), or nothing to recover.
      debugPrint('[capture] nothing recovered: $e');
    }
  }

  /// Opens the camera for [item], remembering the capture first (B10), and
  /// forgetting it once the picker answered normally.
  Future<XFile?> _capture(AssignmentItem item, String ext, Future<XFile?> Function() open) async {
    final repo = ref.read(assignmentsRepoProvider);
    await repo?.db.setSetting(pendingCaptureKey, pendingCaptureJson(widget.assignmentId, item.id, ext));
    final picked = await _openCamera(open);
    await repo?.db.deleteSetting(pendingCaptureKey);
    return picked;
  }

  RoundDraft get _draft => RoundDraft(
    answers: Map.of(_answers),
    photos: {
      for (final e in _newPhotos.entries)
        e.key: [for (final path in e.value) p.basenameWithoutExtension(path)],
    },
  );

  void _persist() {
    final repo = ref.read(assignmentsRepoProvider);
    if (repo == null) return;
    unawaited(
      repo.saveDraft(widget.assignmentId, _draft).catchError((Object e) {
        debugPrint('[draft] save failed: $e');
      }),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// A done item's field shows what was sent. A follow_up item's starts
  /// empty: its answer is the wrong one, quoted in the flag note rather than
  /// offered up for sending again.
  TextEditingController _controllerFor(AssignmentItem item) =>
      _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: _answers[item.id] ??
              (item.status == 'done' ? item.answer ?? '' : ''),
        ),
      );

  /// A cleared choice or an emptied field un-answers the item.
  void _stage(AssignmentItem item, String? raw) {
    setState(() {
      final answer = normalizeAnswer(item.type, raw ?? '');
      if (answer.isEmpty) {
        _answers.remove(item.id);
      } else {
        _answers[item.id] = answer;
      }
    });
    _persist();
  }

  Future<XFile?> _openCamera(Future<XFile?> Function() open) => openCamera(context, open);

  Future<void> _takePhoto(AssignmentItem item) async {
    // Camera only, never the gallery — a photo from the gallery is not
    // evidence of anything (§9). The picker itself compresses (SY-8): a
    // 1600 px long edge at JPEG quality 75, about 300 KB instead of 4 MB.
    final picked = await _capture(
      item,
      'jpg',
      () => ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      ),
    );
    final repo = ref.read(assignmentsRepoProvider);
    if (picked == null || repo == null) return;
    try {
      // Out of the picker's cache, which the OS purges, into the evidence
      // folder, under an id fixed now (LS-1, SY-3).
      final path = await repo.photoPath(await repo.keepPhoto(picked.path));
      setState(() => _newPhotos.putIfAbsent(item.id, () => []).add(path));
      _persist();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Could not keep this photo: $e');
    }
  }

  /// A short clip as evidence. Camera only, like photos — never the gallery.
  /// image_picker cannot compress video, so the length is what keeps it
  /// under the upload limit (50 MB, API and bucket).
  Future<void> _recordVideo(AssignmentItem item) async {
    final picked = await _capture(
      item,
      'mp4',
      () => ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      ),
    );
    final repo = ref.read(assignmentsRepoProvider);
    if (picked == null || repo == null) return;
    try {
      final path = await repo.photoPath(await repo.keepPhoto(picked.path, ext: 'mp4'));
      setState(() => _newPhotos.putIfAbsent(item.id, () => []).add(path));
      _persist();
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Could not keep this video: $e');
    }
  }

  Future<void> _runZoneCheck(ClubZone zone) async {
    if (!mounted) return;
    setState(() => _zoneChecking = true);
    final check = await checkClubZone(zone);
    if (!mounted) return;
    setState(() {
      _zoneCheck = check;
      _zoneChecking = false;
    });
  }

  /// The unknown gate's Retry: GET /me again. clubZoneProvider re-reads when
  /// it lands; a failure says so rather than leave the button looking dead.
  Future<void> _reloadZone() async {
    ref.invalidate(profileFetchProvider);
    try {
      await ref.read(profileFetchProvider.future);
    } catch (_) {
      if (mounted) {
        showErrorSnack(
          context,
          AppLocalizations.of(context)!.syncServerUnreachable,
        );
      }
    }
  }

  /// What stands in for the checklist until the phone is known to be inside
  /// the club, or null to show the checklist. A club with no zone has no
  /// gate. A zone not known yet blocks, fail closed: otherwise a phone that
  /// never reached GET /me would skip the check for good.
  Widget? _zoneGate(AsyncValue<ClubZoneState> zoneAsync) {
    // Still reading the cache: a spinner rather than a flash of the checklist.
    if (zoneAsync.isLoading && !zoneAsync.hasValue) {
      return const _ZoneGate.checking();
    }
    final ClubZone zone;
    switch (zoneAsync.valueOrNull) {
      case NoZone():
        return null;
      case HasZone(zone: final z):
        zone = z;
      case ZoneUnknown() || null: // null: the cache could not be read
        return _ZoneGate(
          check: (state: ZoneState.unknown, metres: 0),
          onRetry: _reloadZone,
        );
    }
    if (_zoneCheck == null && !_zoneChecking) {
      _zoneChecking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runZoneCheck(zone));
    }
    final check = _zoneCheck;
    if (_zoneChecking || check == null) return const _ZoneGate.checking();
    if (check.state == ZoneState.inside) return null;
    return _ZoneGate(check: check, onRetry: () => _runZoneCheck(zone));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    // Again at Submit: the round was opened inside, but the phone may have
    // left since. Outside, nothing is queued and the gate says why; the
    // staged answers stay, so Retry back inside picks up where it was.
    switch (ref.read(clubZoneProvider).valueOrNull) {
      case NoZone():
        break;
      case HasZone(:final zone):
        final check = await checkClubZone(zone);
        if (!mounted) return;
        if (check.state != ZoneState.inside) {
          setState(() {
            _zoneCheck = check;
            _submitting = false;
          });
          return;
        }
      case ZoneUnknown() || null:
        // The gate stops this before Submit shows; fail closed regardless.
        setState(() => _submitting = false);
        return;
    }

    final repo = ref.read(assignmentsRepoProvider)!;

    // Nothing here used to be guarded, and every one of these calls writes to
    // sqflite. A throw left _submitting stuck true — so the button showed a
    // spinner forever, never navigated, and the only way out was backing out
    // to the list, which rebuilt the screen with _submitting false and made it
    // look like Submit simply did nothing, over and over, with the real
    // exception nowhere the user could see it.
    try {
      await repo.queueRound(widget.assignmentId, _draft);
    } catch (e, s) {
      debugPrint('[submit] queueing failed: $e\n$s');
      if (mounted) {
        setState(() => _submitting = false);
        showErrorSnack(context, 'Could not save this round: $e');
      }
      return;
    }
    // The outbox owns them now. Cleared so a second Submit (after backing
    // out of the pad) cannot queue the same photos twice; the queued work
    // shows through the overlay instead (applyLocal).
    setState(() {
      _answers.clear();
      _newPhotos.clear();
    });
    ref.invalidate(myAssignmentsProvider);
    unawaited(ref.read(syncServiceProvider)?.drain());

    if (!mounted) return;
    // Committed before the signature route rather than threaded through it —
    // backing out of signing should not throw the round away.
    await context.push('/tasks/${widget.assignmentId}/signature');
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final assignment = ref.watch(assignmentByIdProvider(widget.assignmentId));

    if (assignment == null) return const RoundGone();

    final readOnly = assignment.isReadOnly;
    // A round that can no longer be filled is only read: no zone check.
    final gate = readOnly ? null : _zoneGate(ref.watch(clubZoneProvider));
    final done = assignment.items
        .where((i) => isItemChecked(i, _answers))
        .length;
    // Cached with the round, so it is there offline.
    final hasNote = assignment.taskNote?.trim().isNotEmpty ?? false;
    // Work already queued on this round (Submit, then back out of the pad):
    // it can go to signing again without staging anything new.
    final queued =
        ref
            .watch(pendingRoundsProvider)
            .valueOrNull
            ?.contains(widget.assignmentId) ??
        false;

    if (gate != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: Column(
            children: [
              _Header(assignment: assignment, done: done),
              Expanded(child: gate),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _Header(assignment: assignment, done: done),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                itemCount: assignment.items.length + (hasNote ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (hasNote && i == 0) {
                    return _Instructions(note: assignment.taskNote!.trim());
                  }
                  final item = assignment.items[hasNote ? i - 1 : i];
                  // A done answer is already on the server and cannot be
                  // taken back; only this session's are reversible. A
                  // follow_up item stays open — re-answering it is the point.
                  final locked = readOnly || item.status == 'done';
                  final typed = item.type == 'number' || item.type == 'text';
                  return SubtaskTile(
                    item: item,
                    staged: _answers[item.id],
                    checked: isItemChecked(item, _answers),
                    locked: locked,
                    photos: itemPhotos(item, _newPhotos),
                    controller: typed ? _controllerFor(item) : null,
                    onAnswer: (raw) => _stage(item, raw),
                    onCamera: () => _takePhoto(item),
                    onVideo: () => _recordVideo(item),
                  );
                },
              ),
            ),
            _BottomBar(
              assignment: assignment,
              answers: _answers,
              newPhotos: _newPhotos,
              queued: queued,
              submitting: _submitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the checklist outside the club's zone: why, and the thing
/// that fixes it. Retry is always there, since the fix (walking in, a
/// settings switch) happens outside this screen.
class _ZoneGate extends StatelessWidget {
  const _ZoneGate({required ZoneCheck this.check, required this.onRetry});
  const _ZoneGate.checking() : check = null, onRetry = null;

  final ZoneCheck? check;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final c = check;
    if (c == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(t.zoneChecking),
          ],
        ),
      );
    }
    final message = switch (c.state) {
      ZoneState.outside => t.zoneOutside(c.metres),
      ZoneState.mocked => t.zoneMocked,
      ZoneState.denied || ZoneState.deniedForever => t.zonePermission,
      ZoneState.serviceOff => t.zoneServiceOff,
      ZoneState.unavailable || ZoneState.inside => t.zoneUnavailable,
      ZoneState.unknown => t.zoneUnknown,
    };
    final (String, Future<bool> Function())? fix = switch (c.state) {
      ZoneState.denied || ZoneState.deniedForever => (
        t.zoneOpenSettings,
        Geolocator.openAppSettings,
      ),
      ZoneState.serviceOff => (
        t.zoneTurnOnLocation,
        Geolocator.openLocationSettings,
      ),
      _ => null,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              c.state == ZoneState.unknown
                  ? Icons.cloud_off_outlined
                  : Icons.location_off_outlined,
              size: 40,
              color: AppColors.cyanDark,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (fix != null) ...[
              FilledButton(onPressed: fix.$2, child: Text(fix.$1)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(t.commonRetry)),
            ] else
              FilledButton(onPressed: onRetry, child: Text(t.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.assignment, required this.done});
  final Assignment assignment;
  final int done;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final a = assignment;

    return AppHeader(
      title: pickLocalized(context, a.titleAr, a.titleEn),
      subtitle: assignmentSubtitle(context, a),
      actions: [
        HeaderIconButton(
          icon: Icons.close,
          label: MaterialLocalizations.of(context).closeButtonLabel,
          // A deep link straight to a task has nothing to pop back to.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/tasks'),
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.taskDetailProgressLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Color(0xB3F3F2F2), // paper @ 70%
                  ),
                ),
                Text(
                  t.tasksProgress(done, a.items.length),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paper,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            TaskProgressBar(
              done: done,
              total: a.items.length,
              height: 8,
              track: TaskProgressBar.onInkTrack,
              fill: TaskProgressBar.fillFor(a.effectiveStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.assignment,
    required this.answers,
    required this.newPhotos,
    required this.queued,
    required this.submitting,
    required this.onSubmit,
  });

  final Assignment assignment;
  final Map<String, String> answers;
  final Map<String, List<String>> newPhotos;
  final bool queued;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (assignment.effectiveStatus == 'expired') {
      return _Bar(
        child: Text(
          t.taskDetailExpiredMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: AppColors.magenta),
        ),
      );
    }
    if (assignment.isReadOnly) return const SizedBox.shrink();

    final missing = missingPhotoCount(assignment, answers, newPhotos);
    final canSubmit =
        (queued || canSubmitStaged(assignment, answers, newPhotos)) &&
        missing == 0;

    return _Bar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: canSubmit && !submitting ? onSubmit : null,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.draw_outlined, size: 22),
                      const SizedBox(width: 8),
                      Text(t.taskDetailSubmitButton),
                    ],
                  ),
          ),
          if (missing > 0) ...[
            const SizedBox(height: 10),
            Text(
              t.taskDetailPhotosMissing(missing),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: Color(0x80201E1D), // text @ 50%
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The creator's instructions (task_note), at the top of the checklist.
class _Instructions extends StatelessWidget {
  const _Instructions({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadius,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.taskInstructions.toUpperCase(), style: kSectionLabel),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontSize: 14.5, height: 1.35)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: child,
      ),
    ),
  );
}
