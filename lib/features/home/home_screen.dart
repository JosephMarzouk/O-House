import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme.dart';
import '../../widgets/ink_handoff_panel.dart';
import '../../widgets/sync_banner.dart';
import '../splash_handoff.dart';
import 'home_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SplashHandoffAnimation<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Safe to call repeatedly — drain() is idempotent per op (§2, §7C).
    ref.read(syncServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final assignments = ref.watch(myAssignmentsProvider).valueOrNull ?? [];

    int count(bool Function(String) match) =>
        assignments.where((a) => match(a.effectiveStatus)).length;

    final topInset = MediaQuery.paddingOf(context).top;
    final idealHeader = topInset + kHomeHeaderContentHeight;
    // Same device-size cap as Login, for the same reason: keyed off the
    // physical screen, not the keyboard-shrunk viewport.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final headerHeight = idealHeader < screenHeight * 0.42
        ? idealHeader
        : screenHeight * 0.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: InkHandoffPanel(
          expanded: expanded,
          collapsedHeight: headerHeight,
          // The overlay draws the logo and text; the panel itself is just
          // the ink-coloured, shrinking box behind them.
          panel: const SizedBox.shrink(),
          overlay: (context, screenSize) => HomeHeaderOverlay(
            expanded: expanded,
            screenSize: screenSize,
            profile: profile,
          ),
          body: _body(t, count),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations t, int Function(bool Function(String)) count) {
    return Column(
      children: [
        const SyncBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatTile(
                    label: t.homeToDo,
                    value: count((s) => s == 'pending'),
                  ),
                  _StatTile(
                    label: t.homeInProgress,
                    value: count((s) => s == 'in_progress'),
                  ),
                  _StatTile(
                    label: t.homeSubmitted,
                    value: count((s) => s == 'submitted'),
                  ),
                  _StatTile(
                    label: t.statusExpired,
                    value: count((s) => s == 'expired'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/tasks'),
                child: Text(t.tasksTitle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
