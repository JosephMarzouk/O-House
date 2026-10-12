import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assignment.dart';
import '../../models/club_zone.dart';
import '../../push/push_service.dart';
import '../../theme.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/ink_handoff_panel.dart';
import '../../widgets/sync_banner.dart';
import '../../widgets/task_card.dart';
import '../assignments/club_zone.dart';
import '../splash_handoff.dart';
import 'home_header.dart';

/// Muted body copy — text @ 55%, the design's colour for the round summary
/// and the Next up meta line.
const _muted = Color(0x8C201E1D);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Once per app process: a refusal is not asked again on every visit.
bool _askedForLocation = false;

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SplashHandoffAnimation<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // The location prompt comes here, as soon as the club turns out to have
    // a zone: sign-in and app start both land on Home, and a question asked
    // up front beats one sprung halfway into a round. A club with no zone is
    // never asked. A refusal is the checklist gate's to explain.
    ref.listenManual(clubZoneProvider, (_, next) {
      if (_askedForLocation || next.valueOrNull is! HasZone) return;
      _askedForLocation = true;
      ensureLocationPermission().ignore();
    }, fireImmediately: true);
    // Notifications (PN-2) are asked here for the same reason, once the ink
    // hand-off has finished, so the dialog never lands mid-animation.
    if (pushAvailable) {
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) askPushPermission(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final assignments = ref.watch(myAssignmentsProvider).valueOrNull ?? [];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: InkHandoffPanel(
          expanded: expanded,
          // Full screen when we came from the splash; Login's header height
          // when we came from Login. Both supplied by the mixin.
          expandedHeight: expandedHeight,
          duration: handoffDuration,
          collapsedHeight: inkHeaderHeight(context, kHomeHeaderContentHeight),
          // The overlay draws the logo and text; the panel itself is just
          // the ink-coloured, shrinking box behind them.
          panel: const SizedBox.shrink(),
          overlay: (context, screenSize) => HomeHeaderOverlay(
            expanded: expanded,
            screenSize: screenSize,
            profile: profile,
            expandedPanelHeight: expandedHeight,
            duration: handoffDuration,
          ),
          body: _body(t, assignments),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations t, List<Assignment> assignments) {
    int count(String status) =>
        assignments.where((a) => a.effectiveStatus == status).length;

    // Today's outstanding work, earliest window first — the scope for both
    // the round summary and Next up. Same predicate the Tasks screen's Today
    // tab uses; it lives on Assignment so there is only one copy.
    final todayOpen =
        assignments.where((a) => a.isToday && !a.isTerminal).toList()..sort(
          (a, b) => (a.windowStart ?? '').compareTo(b.windowStart ?? ''),
        );

    // window_start is zero-padded 'HH:mm:ss', so a plain string sort is
    // chronological. The end is not: an overnight window's ('00:44',
    // tomorrow) sorts first as a string, so the span ends at the window that
    // closes last by its deadline.
    final starts = todayOpen.map((a) => a.windowStart).nonNulls.toList()
      ..sort();
    final closing =
        todayOpen
            .where((a) => a.windowEnd != null && a.deadline != null)
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final hasSpan = starts.isNotEmpty && closing.isNotEmpty;

    return Column(
      children: [
        const SyncBanner(),
        Expanded(
          child: RefreshIndicator(
            // Awaited, so the spinner stays up for the whole round trip.
            // Offline it simply stops; the banner says since when.
            onRefresh: () => refreshRounds(ref),
            color: AppColors.cyan,
            backgroundColor: AppColors.paper,
            // CustomScrollView rather than a ListView so SliverFillRemaining
            // can give the content a bounded height — that is what lets the
            // Spacer below push Next up onto the bottom of the screen while
            // the whole thing still scrolls if it ever outgrows the viewport.
            child: CustomScrollView(
              // Without this the pull gesture is dead whenever the content
              // does not overflow, which on this screen is the normal case.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  // Note the 0 bottom: the nav-bar clearance is a trailing
                  // SizedBox *inside* the column instead. SliverFillRemaining
                  // fills the viewport, so padding out here would only add
                  // scrollable space below it — the Spacer would still shove
                  // Next up to the viewport floor, under the bar.
                  padding: const EdgeInsets.fromLTRB(26, 30, 26, 0),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Two Rows rather than a GridView: the grid is a
                        // fixed 2x2, and a GridView is a viewport, which
                        // cannot report the intrinsic height SliverFillRemaining
                        // needs to measure this column.
                        _StatRow(
                          children: [
                            _StatTile(
                              label: t.homeToDo,
                              value: count('pending'),
                            ),
                            _StatTile(
                              label: t.homeInProgress,
                              // follow_up is in progress from where staff
                              // stand: sent once, but with flagged answers
                              // still theirs to fix. Counting it anywhere
                              // else — Submitted — would say it is done.
                              value: count('in_progress') + count('follow_up'),
                              ground: AppColors.cyanTint,
                              number: AppColors.cyanDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StatRow(
                          children: [
                            _StatTile(
                              label: t.homeSubmitted,
                              value: count('submitted'),
                            ),
                            // Magenta is the app's only alarm colour — this
                            // is the one tile allowed to reach for it.
                            _StatTile(
                              label: t.statusExpired,
                              value: count('expired'),
                              ground: AppColors.magentaTint,
                              number: AppColors.magenta,
                              labelColor: AppColors.magentaDeep,
                            ),
                          ],
                        ),
                        const SizedBox(height: 42),
                        FilledButton(
                          // go, not push: Tasks is a peer tab now, not a
                          // screen stacked on top of Home.
                          onPressed: () => context.go('/tasks'),
                          child: Text(t.tasksTitle),
                        ),
                        if (hasSpan) ...[
                          const SizedBox(height: 12),
                          Text(
                            t.homeRoundSummary(
                              todayOpen.length,
                              starts.first.substring(0, 5),
                              closing.last.windowEnd!.substring(0, 5),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: _muted),
                          ),
                        ],
                        // Next up sits on the bottom of the screen. The gap
                        // is the minimum; the Spacer eats whatever is left
                        // over above it, and collapses to nothing once the
                        // content is tall enough to scroll.
                        const SizedBox(height: 38),
                        const Spacer(),
                        Text(t.homeNextUp, style: kSectionLabel),
                        const SizedBox(height: 14),
                        if (todayOpen.isEmpty)
                          const _NothingUpcoming()
                        else
                          _NextUp(assignment: todayOpen.first),
                        // Clears the floating nav bar the shell paints over
                        // this branch (extendBody).
                        SizedBox(height: 24 + navBarExtent(context)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of two equal status tiles. Fixed height so both rows match whatever
/// their content happens to be, and so the column above stays measurable.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 114,
    child: Row(
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 14),
        Expanded(child: children[1]),
      ],
    ),
  );
}

/// One status count. Takes its colours directly rather than a status string —
/// the four call sites already know which is which, so a status-to-colour
/// switch would be indirection for nothing.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.ground = AppColors.surface,
    this.number = AppColors.text,
    this.labelColor,
  });

  final String label;
  final int value;
  final Color ground;
  final Color number;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ground,
        borderRadius: kRadiusFloating,
        boxShadow: const [kShadowMd],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            // Larger than headlineMedium — the artboard's 600 40px/1.
            style: TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              color: number,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelColor == null
                ? kSectionLabel
                : kSectionLabel.copyWith(color: labelColor),
          ),
        ],
      ),
    );
  }
}

/// Stands in for [_NextUp] when nothing is left outstanding today. Centred
/// under the same section label, so the block keeps its place on the screen
/// instead of the whole layout jumping when the last task is submitted.
class _NothingUpcoming extends StatelessWidget {
  const _NothingUpcoming();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 46,
            color: Color(0x4D201E1D), // ink @ 30%
          ),
          const SizedBox(height: 12),
          Text(
            t.homeNothingUpcoming,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4, color: _muted),
          ),
        ],
      ),
    );
  }
}

/// The next outstanding assignment today, in the exact same card Tasks uses
/// for every row — title, site, window, progress — rather than a bespoke
/// summary line.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) => TaskCard(
    assignment: assignment,
    onTap: () => context.push('/tasks/${assignment.id}'),
  );
}
