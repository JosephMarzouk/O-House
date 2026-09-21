import 'package:flutter/material.dart';

import '../theme.dart';

/// The collapsed ink header height for a screen whose header content is
/// [contentHeight] tall, capped so it never eats a short phone's whole
/// screen. Keyed off the device screen rather than the current viewport, so
/// an opening keyboard doesn't resize the header underneath the form.
///
/// Login and Home both need this number, and Login needs it outside build
/// too (see loginHandoffFromHeight), so it lives here rather than being
/// spelled out twice.
double inkHeaderHeight(BuildContext context, double contentHeight) {
  final ideal = MediaQuery.paddingOf(context).top + contentHeight;
  final cap = MediaQuery.sizeOf(context).height * 0.42;
  return ideal < cap ? ideal : cap;
}

/// The shared "splash hand-off" chrome for Login and Home: an ink panel that
/// opens matching the splash's last frame exactly — full screen, in `panel`
/// — then shrinks to `collapsedHeight` while `body` fades in below. See
/// splash_handoff.dart for when `expanded` starts true vs false.
///
/// `overlay`, if given, draws above both `panel` and `body` in a coordinate
/// space that stays the full screen size throughout — for content (Home's
/// logo) that needs to move on its own path rather than just being recentred
/// inside panel's shrinking box the way Login's does.
class InkHandoffPanel extends StatelessWidget {
  const InkHandoffPanel({
    super.key,
    required this.expanded,
    required this.collapsedHeight,
    required this.panel,
    required this.body,
    this.overlay,
    this.expandedHeight,
    this.duration = const Duration(milliseconds: 1300),
  });

  final bool expanded;
  final double collapsedHeight;

  /// What `expanded` means in pixels. Null is the full screen — the splash's
  /// last frame. Home passes Login's header height when it is arriving from
  /// Login, so the ink continues one motion across the route swap instead of
  /// re-expanding to full screen first.
  final double? expandedHeight;
  final Widget panel;
  final Widget body;
  final Widget Function(BuildContext context, Size screenSize)? overlay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = constraints.biggest;
        return Stack(
          children: [
            // Laid out at its final position from the first frame — the
            // panel simply uncovers it, so nothing reflows mid-animation.
            Positioned.fill(
              top: collapsedHeight,
              child: IgnorePointer(
                // Opacity 0 still hit-tests — without this, a tap during the
                // drag lands on invisible content.
                ignoring: expanded,
                child: AnimatedOpacity(
                  opacity: expanded ? 0 : 1,
                  duration: duration,
                  curve: Curves.easeIn,
                  child: body,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                height: expanded
                    ? (expandedHeight ?? screenSize.height)
                    : collapsedHeight,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  // Rounds in step with the collapse — flat only while it is
                  // genuinely full-bleed, matching the splash, and curved
                  // once it is a header sitting above the paper body.
                  // Arriving from Login it is already a header, so it starts
                  // rounded: squaring off first would pop Login's corners.
                  borderRadius: expanded && expandedHeight == null
                      ? BorderRadius.zero
                      : kRadiusHeader,
                ),
                child: panel,
              ),
            ),
            if (overlay != null)
              Positioned.fill(child: overlay!(context, screenSize)),
          ],
        );
      },
    );
  }
}
