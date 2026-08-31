import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assignment.dart';
import '../../widgets/status_chip.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});
  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final assignments = ref.watch(myAssignmentsProvider).valueOrNull ?? [];
    final today = DateTime.now();
    bool isToday(Assignment a) =>
        a.scheduledDate != null &&
        a.scheduledDate!.year == today.year &&
        a.scheduledDate!.month == today.month &&
        a.scheduledDate!.day == today.day;
    const terminal = {'submitted', 'approved', 'rejected', 'expired'};

    List<Assignment> filter(bool Function(Assignment) predicate) => assignments
        .where(predicate)
        .where(
          (a) =>
              _query.isEmpty ||
              a.titleEn.toLowerCase().contains(_query.toLowerCase()) ||
              a.titleAr.contains(_query),
        )
        .toList();

    final todayList = filter(
      (a) => isToday(a) && !terminal.contains(a.effectiveStatus),
    );
    final upcomingList = filter(
      (a) =>
          !isToday(a) &&
          (a.scheduledDate?.isAfter(today) ?? false) &&
          !terminal.contains(a.effectiveStatus),
    );
    final historyList = filter(
      (a) =>
          terminal.contains(a.effectiveStatus) ||
          (!isToday(a) && (a.scheduledDate?.isBefore(today) ?? false)),
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.tasksTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: t.tasksTabToday),
              Tab(text: t.tasksTabUpcoming),
              Tab(text: t.tasksTabHistory),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: t.tasksSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TaskList(assignments: todayList, emptyText: t.tasksEmpty),
                  _TaskList(assignments: upcomingList, emptyText: t.tasksEmpty),
                  _TaskList(assignments: historyList, emptyText: t.tasksEmpty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.assignments, required this.emptyText});
  final List<Assignment> assignments;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    final t = AppLocalizations.of(context)!;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: assignments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = assignments[i];
        final title = Localizations.localeOf(context).languageCode == 'ar'
            ? a.titleAr
            : a.titleEn;
        return Card(
          child: ListTile(
            onTap: () => context.push('/tasks/${a.id}'),
            title: Text(title.isEmpty ? a.titleEn : title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.siteNameEn != null) Text(a.siteNameEn!),
                if (a.windowStart != null && a.windowEnd != null)
                  Text(
                    t.taskDetailWindow(
                      a.windowStart!.substring(0, 5),
                      a.windowEnd!.substring(0, 5),
                    ),
                  ),
                Text(t.tasksProgress(a.doneCount, a.items.length)),
              ],
            ),
            isThreeLine: true,
            trailing: StatusChip(
              status: a.effectiveStatus,
              wasExtended: a.wasExtended,
            ),
          ),
        );
      },
    );
  }
}
