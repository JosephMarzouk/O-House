import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/splash_handoff.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Height of the bar's own content, above its bottom gutter. Fixed rather
/// than derived so [navBarExtent] can be exact — same reason
/// kHomeHeaderContentHeight is a constant.
const kNavBarContentHeight = 68.0;

/// Total space the floating bar covers. The shell paints its branches under
/// the bar (`extendBody: true`, so the splash hand-off's ink can reach the
/// bottom of the screen), which means every scrollable branch owes its last
/// row this much bottom padding or it ends up unreachable beneath the bar.
double navBarExtent(BuildContext context) {
  final inset = MediaQuery.paddingOf(context).bottom;
  return kNavBarContentHeight + (inset > 12 ? inset : 12);
}

/// The floating Home / Assignments / Profile bar shared by the three shell
/// branches (see router.dart).
///
/// Stateful only because of the splash hand-off: Home's [InkHandoffPanel]
/// fills the shell's *body*, which now stops above this bar — so on the first
/// frame after the splash the bar would sit in paper beneath an otherwise
/// all-ink screen, a seam the splash itself never shows. It rides up on the
/// same 1300ms curve instead, arriving as the ink finishes collapsing.
class AppNavBar extends StatefulWidget {
  const AppNavBar({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> {
  Duration _duration = kSplashHandoffDuration;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Read both hand-off flags, never write them — HomeScreen's mixin owns
    // the flip and the clear, and its initState runs after this one (parent
    // builds first), so both read the same pre-flip values and agree on
    // whether to animate.
    //
    // Login has no nav bar, so arriving from Login the bar rides up on that
    // hand-off's curve too; appearing at full opacity while everything else
    // is still crossfading reads as a pop.
    final fromLogin = loginHandoffFromHeight != null;
    _duration = fromLogin ? kLoginHandoffDuration : kSplashHandoffDuration;
    _visible = splashHandoffPlayed && !fromLogin;

    if (!_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final index = widget.shell.currentIndex;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: Padding(
        // Inset on three sides so the bar reads as floating over the paper
        // rather than as a docked edge. The design's 26px bottom gutter is
        // really the home indicator, so defer to the real inset when there
        // is one.
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomInset > 12 ? bottomInset : 12,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.paper,
            borderRadius: kRadiusFloating,
            boxShadow: [kShadowMd],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: kNavBarContentHeight,
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: t.navHome,
                    selected: index == 0,
                    onTap: () => _go(0),
                  ),
                  _NavItem(
                    icon: Icons.checklist_rounded,
                    label: t.tasksTitle,
                    selected: index == 1,
                    onTap: () => _go(1),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: t.profileTitle,
                    selected: index == 2,
                    onTap: () => _go(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `initialLocation: true` only when re-tapping the current tab, which is
  /// the standard "tap Home again to pop back to the top" behaviour.
  void _go(int i) =>
      widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Colour and weight carry the selected state on their own — no separate
    // filled/outlined icon pair to keep in sync.
    // cyanDark, not cyan: the label is text on paper, and some clubs' accent
    // (RYZE's orange, 1.9:1) is too light to read there.
    final color = selected ? AppColors.cyanDark : const Color(0x80201E1D);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: kRadiusFloating,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
