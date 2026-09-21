import 'package:flutter/material.dart';

import '../theme.dart';
import 'brand_logo.dart';

/// The ink block at the top of every screen.
///
/// Before this widget there were three copies of it — appBarTheme, the panel
/// inside InkHandoffPanel, and a hand-rolled Container on each of the two
/// assignments screens — sitting at four different heights, with the logo on
/// only three screens in the app. One widget now owns the colour, the radius,
/// the logo's resting position and the standard height.
///
/// Home is the one screen that cannot use it: its ink block animates up from
/// the splash, so the block is an AnimatedContainer and its content is a
/// full-screen overlay. It matches by sharing [kHeaderContentHeight] instead.
///
/// ponytail: AppBar is still themed for the two loading-state stubs that show
/// a bare AppBar() while an assignment resolves; drop it once those have a
/// real skeleton.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.content,
    this.actions = const <Widget>[],
    this.bottom,
    this.showLogo = true,
  }) : assert(
         title != null || content != null,
         'AppHeader needs either title or content',
       );

  final String? title;

  /// One line under the title — site, date and window, or a name and role.
  final String? subtitle;

  /// Replaces the title/subtitle column entirely — for a screen whose header
  /// needs more than one label and one line under it (Profile reuses Home's
  /// own date/name/role block via [HeaderText] so the two headers show
  /// exactly the same content, not just the same chrome).
  final Widget? content;

  /// A 44x44 control — normally a close button — that takes the logo's own
  /// top-end slot. Given any actions, the logo does not also render: the two
  /// never share that corner.
  final List<Widget> actions;

  /// Anything that belongs inside the ink but below the title row: the search
  /// field and tab row on Tasks, the progress bar on a task, a status chip on
  /// a submitted round.
  final Widget? bottom;

  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: kRadiusHeader,
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      // A minimum, not a fixed height: `bottom` (Tasks' tab row, a task's
      // progress bar...) can push a screen's header past it, but nothing
      // shrinks below it. mainAxisSize.min + mainAxisAlignment.center (rather
      // than the old Expanded+Center) is what lets that minimum coexist with
      // growing past it — an Expanded here would demand a bounded height even
      // when this Container's own incoming constraint is unbounded.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kHeaderContentHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child:
                        content ??
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Both capped at one line, which is what
                            // actually holds every header to the same
                            // depth: a long site name or a wordy title
                            // would otherwise wrap and push that screen's
                            // ink deeper than its neighbours'.
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 25,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5, // -.02em
                                color: AppColors.paper,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.3,
                                  color: Color(0xA6F3F2F2), // paper @ 65%
                                ),
                              ),
                            ],
                          ],
                        ),
                  ),
                  // A close button claims the logo's own corner — the two
                  // never appear together. The logo shows only when
                  // nothing else is claiming it.
                  if (actions.isNotEmpty)
                    for (final action in actions) ...[
                      const SizedBox(width: 12),
                      action,
                    ]
                  else if (showLogo) ...[
                    const SizedBox(width: 12),
                    const SizedBox(width: 44, height: 44, child: BrandLogo()),
                  ],
                ],
              ),
            ),
            ?bottom,
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Screen-reader label; there is no visible text on these.
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: kRadius,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x1FF3F2F2), // paper @ 12%
            borderRadius: kRadius,
          ),
          child: Icon(icon, size: 20, color: AppColors.paper),
        ),
      ),
    ),
  );
}
