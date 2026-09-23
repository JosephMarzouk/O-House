import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_text.dart';
import '../models/assignment_item.dart';
import '../theme.dart';
import 'photo_thumb.dart';

/// One place inside a round (artboard 1d): what to check, the control that
/// answers it, and a separate camera button.
///
/// The control follows the item's type — a Yes/No or Pass/Fail pair, a number
/// field, a text field — because mark_item_done() now weighs an answer against
/// the item's `correct` rule (0013), and a bare tick carries nothing to weigh.
/// That is also why the tile body no longer toggles anything: a tap on "Pool
/// deck" cannot say which answer it means.
///
/// There is deliberately no way to remove a photo. attach_item_photo() is
/// array_append server-side and nothing deletes from it, so an affordance to
/// undo would be a lie — evidence, once taken, stands.
class SubtaskTile extends StatelessWidget {
  const SubtaskTile({
    super.key,
    required this.item,
    required this.staged,
    required this.checked,
    required this.locked,
    required this.photos,
    required this.onAnswer,
    required this.onCamera,
    this.controller,
  });

  final AssignmentItem item;

  /// This session's answer, if any, in wire form.
  final String? staged;

  /// Answered — done on the server or staged here. Drives the status box,
  /// which is a glyph now, not a control.
  final bool checked;

  /// Already committed, or the whole round is read-only — the answer cannot
  /// be changed and the camera is closed.
  final bool locked;

  /// Committed paths plus anything staged this session, merged by the caller.
  final List<String> photos;

  /// A number or text item's field controller. The screen owns it because it
  /// outlives this tile: the list builds lazily and drops a tile scrolled out
  /// of reach, typed value and all. Null for the choice types.
  final TextEditingController? controller;

  /// A choice's value, or a field's raw text; null clears the answer.
  final ValueChanged<String?> onAnswer;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = pickLocalized(context, item.textAr, item.textEn);
    final rejected = item.status == 'rejected';

    // No `checked` semantics on the tile any more. It was a real checkbox when
    // a tap on it ticked; now a screen reader would announce a checkbox that
    // double-tapping does nothing to. The controls speak for the answer
    // instead: the picked choice is `selected`, a field reads its value.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: kRadius,
        boxShadow: [kShadowMd],
      ),
      // Transparent, so the controls' ink lands on the card's ground instead
      // of on the Scaffold's, underneath it.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Check(checked: checked, locked: locked),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: item.critical
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (item.requiresPhoto) ...[
                      const SizedBox(height: 7),
                      _PhotoBadge(
                        label: t.taskDetailPhotoRequired,
                        satisfied: photos.isNotEmpty,
                      ),
                    ],
                    if (rejected && item.rejectNote != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.cancel,
                            size: 16,
                            color: AppColors.magenta,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              t.taskDetailRejectedReason(item.rejectNote!),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.magenta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.isFollowUp) ...[
                      const SizedBox(height: 8),
                      _FollowUpNote(item: item),
                    ],
                    const SizedBox(height: 10),
                    _answerControl(t),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CameraButton(
                assignmentId: item.assignmentId,
                photos: photos,
                onPressed: locked ? null : onCamera,
                label: t.itemSheetTakePhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What a choice shows as picked is this session's answer, else the one a
  /// done item was sent with — never a follow_up item's. That one is the
  /// wrong answer, and showing it picked would read as answered while the
  /// item is waiting on a new one. (A field's text is the controller's,
  /// seeded the same way by the screen.)
  Widget _answerControl(AppLocalizations t) {
    final shown = staged ?? (item.status == 'done' ? item.answer : null);
    final onChanged = locked ? null : onAnswer;
    return switch (item.type) {
      'number' || 'text' => _AnswerField(
        controller: controller,
        number: item.type == 'number',
        hint: item.type == 'number' ? t.answerNumberHint : t.answerTextHint,
        onChanged: onChanged,
      ),
      'pass_fail' => _ChoicePair(
        first: ('pass', t.answerPass),
        second: ('fail', t.answerFail),
        selected: shown,
        onChanged: onChanged,
      ),
      // yesno, and — as the column's own default — any type this build does
      // not know, which still gets an answer rather than no control at all.
      _ => _ChoicePair(
        first: ('yes', t.answerYes),
        second: ('no', t.answerNo),
        selected: shown,
        onChanged: onChanged,
      ),
    };
  }
}

/// Two answers side by side, Yes/No or Pass/Fail. Tapping the picked one
/// again clears it, so a slip of a gloved thumb is undone the way it was
/// made — as a tick used to be.
///
/// Both picked states are cyan, No and Fail included. A "no" is not an alarm
/// — it can be exactly the right answer — and magenta is kept for the one
/// state that is: the follow-up flag.
class _ChoicePair extends StatelessWidget {
  const _ChoicePair({
    required this.first,
    required this.second,
    required this.selected,
    required this.onChanged,
  });

  final (String value, String label) first;
  final (String value, String label) second;
  final String? selected;

  /// Null when locked.
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _choice(first)),
      const SizedBox(width: 8),
      Expanded(child: _choice(second)),
    ],
  );

  Widget _choice((String, String) option) {
    final (value, label) = option;
    final picked = selected == value;
    return Opacity(
      // Once locked, only the answer that was NOT given dims, as far as the
      // camera button does. The one that was sent stays at full strength —
      // dimming the pair as a whole left the committed answer the faintest
      // thing on the card.
      opacity: onChanged == null && !picked ? 0.4 : 1,
      child: Semantics(
        button: true,
        selected: picked,
        enabled: onChanged != null,
        // Each choice is its own Material: the splash then paints over the
        // picked cyan rather than under it, and the Opacity above reaches the
        // fill and border too. An Ink decoration would not — it paints on the
        // tile's Material, outside any Opacity between the two.
        child: Material(
          color: picked ? AppColors.cyan : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: kRadiusControl,
            side: BorderSide(
              color: picked ? AppColors.cyan : AppColors.divider,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onChanged == null
                ? null
                : () => onChanged!(picked ? null : value),
            child: ConstrainedBox(
              // 48, not the 56 of a primary: two of these sit in every tile.
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                    color: picked ? AppColors.paper : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A number or free-text answer. The number field stays left-to-right in
/// Arabic, as the phone row on Login does: typed right-to-left, "-3.5"
/// reorders under the bidi rules into something that is not the number.
class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.number,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController? controller;
  final bool number;

  /// Also the field's accessible name — there is no visible label.
  final String hint;

  /// Null when locked.
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      enabled: onChanged != null,
      onChanged: onChanged,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 17, height: 1.3),
      decoration: InputDecoration(hintText: hint),
    );
    return number
        ? Directionality(textDirection: TextDirection.ltr, child: field)
        : field;
  }
}

/// Why a flagged item is open again — and the only place its expected answer
/// is ever shown: after a miss, never before, so it cannot steer a first
/// answer. The tint and ink are the follow_up chip's own.
class _FollowUpNote extends StatelessWidget {
  const _FollowUpNote({required this.item});
  final AssignmentItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // The latest answer, which is the wrong one for as long as the item is
    // flagged; flagged_answer only keeps the first miss, as history.
    final given = item.answer ?? item.flaggedAnswer;
    final expected = formatCorrect(context, item.correct);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.magentaTint,
        borderRadius: kRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, size: 16, color: AppColors.magenta),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              [
                t.followUpNeeded,
                if (given != null)
                  t.followUpYouAnswered(formatAnswer(context, given)),
                if (expected != null) t.followUpExpected(expected),
              ].join(' · '),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.magentaDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.checked, required this.locked});
  final bool checked;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: checked ? AppColors.cyan : Colors.transparent,
      borderRadius: kRadius,
      border: checked
          ? null
          : Border.all(
              color: const Color(0x52201E1D), // text @ 32%
              width: 1.5,
            ),
    ),
    child: checked
        ? Icon(
            // A committed tick reads as locked, not merely ticked — it is the
            // one thing on this screen that cannot be taken back.
            locked ? Icons.lock : Icons.check,
            size: locked ? 15 : 19,
            color: AppColors.paper,
          )
        : null,
  );
}

/// Turns from a demand into a confirmation once a photo exists, so the user can
/// see at a glance which places are still holding up the submit button.
class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.label, required this.satisfied});
  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final ink = satisfied ? AppColors.cyanDark : AppColors.magenta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: satisfied ? AppColors.cyanTint : AppColors.magentaTint,
        borderRadius: kRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.photo_camera,
            size: 13,
            color: ink,
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.55, // .05em
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.assignmentId,
    required this.photos,
    required this.onPressed,
    required this.label,
  });
  final String assignmentId;
  final List<String> photos;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Widget face = photos.isEmpty
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: kRadius,
              border: Border.all(
                color: const Color(0x52201E1D), // text @ 32%
              ),
            ),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.photo_camera_outlined,
                size: 22,
                color: Color(0x99201E1D), // text @ 60%
              ),
            ),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              PhotoThumb(
                assignmentId: assignmentId,
                path: photos.last,
                size: 48,
              ),
              if (photos.length > 1)
                PositionedDirectional(
                  end: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyan,
                      borderRadius: kRadius,
                    ),
                    child: Text(
                      '${photos.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.paper,
                      ),
                    ),
                  ),
                ),
            ],
          );

    return Semantics(
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: kRadius,
          child: Opacity(opacity: onPressed == null ? 0.4 : 1, child: face),
        ),
      ),
    );
  }
}
