import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/brand_wordmark.dart';

/// Height of the collapsed header's own content, below the safe-area inset:
/// the date/name/role block with the design's padding. Exported so
/// HomeScreen can size InkHandoffPanel's collapsedHeight around it.
const kHomeHeaderContentHeight = kHeaderContentHeight;

const _logoExpandedSize = 96.0;
const _logoCollapsedSize = 44.0;
const _collapsedInset = 26.0; // matches the design's header padding
const _expandedWordmarkGap = 22.0; // matches BrandPanel's own logo-to-text gap

/// Home's animated header content — the counterpart to Login's static
/// `Center(child: BrandPanel())`. Pass this as InkHandoffPanel's `overlay`;
/// it needs the full, stable screen size (not the ink panel's own shrinking
/// box) to compute the expanded/collapsed target rects.
///
/// Two different kinds of motion, on purpose:
/// - The logo glides — position *and* size — from centred/96px (matching the
///   splash exactly) to top-right/44px. One widget, tweened continuously, not
///   two images crossfading — that's what makes it literal.
/// - The text crossfades, because it has to: "O House" / the subtitle isn't
///   a resize of "Wednesday, 26 August" / a name / a role, it's different
///   words. Fading is the honest way to swap unrelated text.
class HomeHeaderOverlay extends StatelessWidget {
  const HomeHeaderOverlay({
    super.key,
    required this.expanded,
    required this.screenSize,
    required this.profile,
    this.expandedPanelHeight,
    this.duration = const Duration(milliseconds: 1300),
  });

  final bool expanded;
  final Size screenSize;
  final Profile? profile;

  /// Height of the ink panel in its expanded state, or null for the full
  /// screen. The logo starts centred in *this* box, so arriving from Login
  /// (whose panel is only its own header tall) begins the glide exactly on
  /// Login's logo rather than jumping to screen centre first.
  final double? expandedPanelHeight;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    // A centred element sits the same distance from either edge, so this one
    // number works as the logo's "end" inset in its expanded state too —
    // keeps the animation on a single direction-aware property (`end`)
    // instead of jumping between `start` and `end` as it collapses.
    final expandedLogoInset = (screenSize.width - _logoExpandedSize) / 2;
    final expandedLogoTop = _expandedLogoTop(topInset);
    final collapsedTextTop = topInset + 20;
    // Centred against the text block, the same way AppHeader centres
    // Profile's logo against its (identical) date/name/role column — not
    // pinned to the top line the way sharing one `top` with the text would.
    final collapsedLogoTop =
        collapsedTextTop + (_collapsedTextBlockHeight - _logoCollapsedSize) / 2;

    return Stack(
      children: [
        // Expanded: "O House" + subtitle, parked directly under wherever the
        // expanded logo sits — matches the splash pixel for pixel.
        Positioned(
          top: expandedLogoTop + _logoExpandedSize + _expandedWordmarkGap,
          left: 0,
          right: 0,
          // Opacity 0 still hit-tests, and once collapsed this sits well down
          // the paper body — where it silently ate scrolls and taps aimed at
          // the content behind it. The logo below has always guarded itself
          // the same way.
          child: IgnorePointer(
            ignoring: !expanded,
            child: AnimatedOpacity(
              opacity: expanded ? 1 : 0,
              duration: duration,
              curve: Curves.easeOut,
              child: const BrandWordmark(),
            ),
          ),
        ),

        // Collapsed: date / name / role, start-aligned, with room at the end
        // for the logo's final spot — mirrors under RTL along with it.
        Positioned.directional(
          textDirection: textDirection,
          top: collapsedTextTop,
          start: _collapsedInset,
          end: _collapsedInset + _logoCollapsedSize + 16,
          child: AnimatedOpacity(
            opacity: expanded ? 0 : 1,
            duration: duration,
            curve: Curves.easeIn,
            child: HeaderText(profile: profile),
          ),
        ),

        // The literal glide — position and size, one widget, continuously
        // tweened between the two states above. `end`-based in both states
        // (see expandedLogoInset) so it lands at the *start* corner under
        // RTL, matching the design's mirrored layout, not stuck at the
        // physical right.
        AnimatedPositionedDirectional(
          duration: duration,
          curve: Curves.easeOutCubic,
          end: expanded ? expandedLogoInset : _collapsedInset,
          top: expanded ? expandedLogoTop : collapsedLogoTop,
          width: expanded ? _logoExpandedSize : _logoCollapsedSize,
          height: expanded ? _logoExpandedSize : _logoCollapsedSize,
          child: IgnorePointer(
            // Only a tap target once it's actually sitting in the corner —
            // tapping the splash-matching centred logo shouldn't do anything.
            ignoring: expanded,
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: const BrandLogo(),
            ),
          ),
        ),
      ],
    );
  }

  // Matches SafeArea(bottom: false)'s own behaviour: it insets by topInset
  // from the top, then centres its child in what's left.
  double _expandedLogoTop(double topInset) {
    final panelHeight = expandedPanelHeight ?? screenSize.height;
    final availableHeight = panelHeight - topInset;
    return topInset + (availableHeight - _expandedBlockHeight) / 2;
  }

  // logo + gap + title line + gap + subtitle line, as one centred block —
  // duplicates BrandPanel's own spacing (theme.dart's headlineMedium is
  // 34px/1.1, the subtitle is a fixed 13.5px/1.4) so the wordmark above lines
  // up under the animated logo instead of under BrandPanel's own separate
  // copy of the same numbers. Update both if either changes.
  static const _expandedBlockHeight =
      _logoExpandedSize + _expandedWordmarkGap + (34 * 1.1) + 7 + (13.5 * 1.4);

  // date line + gap + name line + gap + role line, the same three lines
  // HeaderText renders — duplicates its own font sizes/line heights so the
  // logo above can centre on this block without measuring it. Update both
  // if either changes.
  static const _collapsedTextBlockHeight =
      (13.5 * 1.3) + 5 + (26 * 1.15) + 5 + (13.5 * 1.3);
}

/// The collapsed header's date/name/role block. Public so Profile's static
/// header can show the exact same content Home's collapsed header does.
class HeaderText extends StatelessWidget {
  const HeaderText({super.key, required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat('EEEE, d MMMM', locale).format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.3,
            color: Color(0x99F3F2F2),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          profile?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppColors.paper),
        ),
        if (roleLabel(profile) != null) ...[
          const SizedBox(height: 5),
          // No department field on Profile (design shows
          // "Housekeeping · Aquatics") — role is the closest available
          // stand-in until that data exists.
          Text(
            roleLabel(profile)!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.3,
              color: Color(0x99F3F2F2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Title-cased role ('cleaner' -> 'Cleaner'), or null while the profile
/// hasn't loaded yet.
String? roleLabel(Profile? profile) {
  final role = profile?.role;
  if (role == null || role.isEmpty) return null;
  return role[0].toUpperCase() + role.substring(1);
}
