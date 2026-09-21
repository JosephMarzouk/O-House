import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localized_text.dart';
import '../models/assignment_item.dart';
import '../theme.dart';
import 'photo_thumb.dart';

/// One place inside a round (artboard 1d). Tapping anywhere on the tile ticks
/// it; the trailing button is a separate tap target that goes straight to the
/// camera.
///
/// There is deliberately no way to remove a photo. attach_item_photo() is
/// array_append server-side and nothing deletes from it, so an affordance to
/// undo would be a lie — evidence, once taken, stands.
class SubtaskTile extends StatelessWidget {
  const SubtaskTile({
    super.key,
    required this.item,
    required this.checked,
    required this.locked,
    required this.photos,
    required this.onToggle,
    required this.onCamera,
  });

  final AssignmentItem item;
  final bool checked;

  /// Already committed, or the whole round is read-only — the tick cannot be
  /// taken back and the camera is closed.
  final bool locked;

  /// Committed paths plus anything staged this session, merged by the caller.
  final List<String> photos;

  final VoidCallback? onToggle;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = pickLocalized(context, item.textAr, item.textEn);
    final rejected = item.status == 'rejected';

    return Semantics(
      checked: checked,
      enabled: !locked,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: kRadius,
          boxShadow: [kShadowMd],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: locked ? null : onToggle,
            borderRadius: kRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Row(
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
                                    t.taskDetailRejectedReason(
                                      item.rejectNote!,
                                    ),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CameraButton(
                      photos: photos,
                      onPressed: locked ? null : onCamera,
                      label: t.itemSheetTakePhoto,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    required this.photos,
    required this.onPressed,
    required this.label,
  });
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
              PhotoThumb(path: photos.last, size: 48),
              if (photos.length > 1)
                PositionedDirectional(
                  end: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
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
