import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assignment.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/task_card.dart';

/// §6, screen 5 — artboard 1c. The three day buckets live inside the ink
/// header; search sits just below it, first thing in the body.
enum TaskTab { today, upcoming, history }

/// Which bucket an assignment belongs to, by scheduled *day* — not by status.
/// The design's Today tab shows in-progress, overdue, rejected and submitted
/// rounds side by side, because "what did my day look like" is the question
/// the screen answers.
///
/// A total partition on purpose: every assignment lands in exactly one tab,
/// and an undated one shows up in Today rather than disappearing.
///
/// The one exception to "by day" is checked first: a follow_up round is in
/// Today whatever its date. It never expires and its flagged answers are
/// waiting on this person, so filing it under History by the day it was first
/// sent would bury the one old round that still needs them.
///
/// The other: an overnight window still open after midnight stays in Today
/// (Assignment.isTodayAt), since it can still be filled.
TaskTab tabFor(Assignment a, DateTime now) {
  if (a.effectiveStatus == 'follow_up') return TaskTab.today;
  final d = a.scheduledDate;
  if (d == null) return TaskTab.today;
  // A multi-day task is Today on every one of its days, from the first
  // through the last.
  if (a.isTodayAt(now)) return TaskTab.today;
  final first = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  return first.isAfter(today) ? TaskTab.upcoming : TaskTab.history;
}

/// Title *and* site, in both languages — searching "pool" should find the
/// swimming pool round whichever language the app is currently in.
bool matchesQuery(Assignment a, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final lower = q.toLowerCase();
  bool hit(String? s) => s != null && s.toLowerCase().contains(lower);
  return hit(a.titleEn) ||
      hit(a.titleAr) ||
      hit(a.siteNameEn) ||
      hit(a.siteNameAr);
}

/// One row of the Tasks list: a single checklist, or a task over several
/// places shown as one card (QA). [places] holds the one checklist, or the
/// task's checklists in this tab.
typedef TaskEntry = ({String? groupId, List<Assignment> places});

/// The rows of one tab: [inTab] (that tab's checklists, in list order) with a
/// task's places collapsed into one entry where its first place stands.
///
/// A task is in when any of its places, or its own name, matches [query]; it
/// then keeps all its places in this tab, so its counts stay whole. Only a
/// real group collapses (Assignment.isGrouped): with an API older than QR
/// places nothing has a group, and every card is exactly as before.
///
/// Pure, unit-tested.
List<TaskEntry> taskEntries(List<Assignment> inTab, String query) {
  final groups = <String, List<Assignment>>{};
  for (final a in inTab) {
    if (a.isGrouped) groups.putIfAbsent(a.groupId!, () => []).add(a);
  }
  bool groupHit(List<Assignment> places) {
    final q = query.trim().toLowerCase();
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);
    final a = places.first;
    return places.any((p) => matchesQuery(p, query)) ||
        hit(a.groupTitleEn) ||
        hit(a.groupTitleAr);
  }

  final seen = <String>{};
  return [
    for (final a in inTab)
      if (!a.isGrouped) ...[
        if (matchesQuery(a, query)) (groupId: null, places: [a]),
      ] else if (seen.add(a.groupId!) && groupHit(groups[a.groupId!]!))
        (groupId: a.groupId, places: groups[a.groupId!]!),
  ];
}

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});
  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  String _query = '';
  TaskTab _tab = TaskTab.today;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final assignments = ref.watch(myAssignmentsProvider).valueOrNull ?? [];
    final now = DateTime.now();

    final visible = taskEntries(
      assignments.where((a) => tabFor(a, now) == _tab).toList(),
      _query,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: Column(
          children: [
            _Header(
              title: t.tasksTitle,
              tab: _tab,
              onTab: (v) => setState(() => _tab = v),
            ),
            Padding(
              // Top gap matches the ListView's own top padding below, so the
              // search field sits exactly as far from the header as the
              // first task card sits from the search field.
              padding: const EdgeInsets.fromLTRB(22, 15, 22, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: t.tasksSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => refreshRounds(ref),
                color: AppColors.cyan,
                backgroundColor: AppColors.paper,
                child: visible.isEmpty
                    ? _Empty(text: t.tasksEmpty)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // extendBody is on in the shell, so the last card owes
                        // itself clearance from the floating nav bar.
                        padding: EdgeInsets.fromLTRB(
                          22,
                          22,
                          22,
                          22 + navBarExtent(context),
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final e = visible[i];
                          return e.groupId == null
                              ? TaskCard(
                                  assignment: e.places.single,
                                  onTap: () => context.push(
                                    '/tasks/${e.places.single.id}',
                                  ),
                                )
                              : GroupCard(
                                  places: e.places,
                                  onTap: () =>
                                      context.push('/groups/${e.groupId}'),
                                );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.tab, required this.onTab});

  final String title;
  final TaskTab tab;
  final ValueChanged<TaskTab> onTab;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppHeader(
      title: title,
      // Even thirds across the header rather than a left-anchored cluster —
      // each label centers in its own third, so the three stay aligned
      // across the width however long the current locale's word is, instead
      // of leaving dead space trailing them.
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(26, 35, 26, 0),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: _TabLabel(
                  label: t.tasksTabToday,
                  selected: tab == TaskTab.today,
                  onTap: () => onTab(TaskTab.today),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _TabLabel(
                  label: t.tasksTabUpcoming,
                  selected: tab == TaskTab.upcoming,
                  onTap: () => onTab(TaskTab.upcoming),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _TabLabel(
                  label: t.tasksTabHistory,
                  selected: tab == TaskTab.history,
                  onTap: () => onTab(TaskTab.history),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text row with a 3px rule under the active one, not a Material TabBar —
/// the same reasoning as LanguageToggle: losing TabBar's indicator, ripple
/// and equal-width distribution costs more override than writing it out.
class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.cyan : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.paper
                : const Color(0x8CF3F2F2), // paper @ 55%
          ),
        ),
      ),
    ),
  );
}

/// A ListView rather than a Center, so the pull-to-refresh gesture still
/// works on an empty tab.
class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(26, 90, 26, navBarExtent(context)),
    children: [
      const Icon(
        Icons.checklist_rounded,
        size: 44,
        color: Color(0x4D201E1D), // ink @ 30%
      ),
      const SizedBox(height: 14),
      Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0x8C201E1D), // text @ 55%
        ),
      ),
    ],
  );
}
