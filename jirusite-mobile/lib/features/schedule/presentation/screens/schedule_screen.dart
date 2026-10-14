import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared_widgets/empty_state.dart';

final _scheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.projectSchedule(projectId));
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheduleAsync = ref.watch(_scheduleProvider(projectId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(title: Text(l.schedule)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.addTask),
        backgroundColor: AppColors.safetyOrange,
        foregroundColor: Colors.white,
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_month_outlined,
              title: l.noTasksScheduled,
              actionLabel: l.addTask,
              onAction: () => _showAddTaskDialog(context, ref),
            );
          }

          // Compute overall completion
          final totalPct = tasks.isEmpty
              ? 0
              : tasks.fold<int>(
                      0,
                      (s, t) =>
                          s + (t['percent_complete'] as int? ?? 0)) ~/
                  tasks.length;
          final complete =
              tasks.where((t) => t['status'] == 'complete').length;
          final delayed =
              tasks.where((t) => t['status'] == 'delayed').length;

          // Group by cost code
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final t in tasks) {
            final key = t['cost_code_name'] as String? ?? 'General';
            grouped.putIfAbsent(key, () => []).add(t);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ScheduleSummaryCard(
                  totalPct: totalPct,
                  total: tasks.length,
                  complete: complete,
                  delayed: delayed,
                  tasks: tasks,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entries =
                          grouped.entries.toList();
                      final group = entries[index];
                      return _TaskGroup(
                        groupName: group.key,
                        tasks: group.value,
                        projectId: projectId,
                        onRefresh: () =>
                            ref.invalidate(_scheduleProvider(projectId)),
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.concrete,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.newTask,
                        style:
                            Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l.taskName,
                    border: const OutlineInputBorder(),
                    prefixIcon:
                        const Icon(Icons.task_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.safetyOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final dio = ref.read(dioClientProvider);
                      await dio.post(
                          ApiEndpoints.projectSchedule(projectId),
                          data: {'name': nameCtrl.text.trim()});
                      ref.invalidate(_scheduleProvider(projectId));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(l.add,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.totalPct,
    required this.total,
    required this.complete,
    required this.delayed,
    required this.tasks,
  });
  final int totalPct;
  final int total;
  final int complete;
  final int delayed;
  final List<Map<String, dynamic>> tasks;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final healthColor = delayed > 0
        ? AppColors.rebarRust
        : totalPct >= 80
            ? AppColors.levelGreen
            : AppColors.safetyOrange;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.blueprintInk, healthColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.blueprintInk.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.percentComplete,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text('$totalPct%',
                        style: AppTextStyles.numeric.copyWith(
                            fontSize: 32, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Pill(label: '$total tasks'),
                  const SizedBox(height: 4),
                  _Pill(
                      label: '$complete ${l.complete.toLowerCase()}',
                      color: AppColors.levelGreen),
                  if (delayed > 0) ...[
                    const SizedBox(height: 4),
                    _Pill(
                        label: '$delayed ${l.delayed.toLowerCase()}',
                        color: AppColors.rebarRust),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalPct / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(healthColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color ?? Colors.white,
                fontWeight: FontWeight.w600)),
      );
}

// ── Task group ────────────────────────────────────────────────────────────────

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.groupName,
    required this.tasks,
    required this.projectId,
    required this.onRefresh,
  });
  final String groupName;
  final List<Map<String, dynamic>> tasks;
  final String projectId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Container(
                width: 4, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.safetyOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(groupName.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.concrete.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${tasks.length}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _TaskCard(
            task: t, projectId: projectId, onRefresh: onRefresh)),
      ],
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.task,
    required this.projectId,
    required this.onRefresh,
  });
  final Map<String, dynamic> task;
  final String projectId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = task['status'] as String? ?? 'not_started';
    final percent = task['percent_complete'] as int? ?? 0;
    final color = switch (status) {
      'complete'    => AppColors.levelGreen,
      'in_progress' => AppColors.safetyOrange,
      'delayed'     => AppColors.rebarRust,
      _             => AppColors.textSecondary,
    };
    final statusLabel = switch (status) {
      'complete'    => l.complete,
      'in_progress' => l.inProgress,
      'delayed'     => l.delayed,
      _             => l.notStarted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 40, height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 3.5,
                        backgroundColor:
                            color.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation(color),
                      ),
                      Text('$percent%',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['name'] as String,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (task['planned_start'] != null ||
                          task['planned_end'] != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${task['planned_start'] ?? '?'} → ${task['planned_end'] ?? '?'}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: percent.toDouble(),
                min: 0, max: 100, divisions: 20,
                label: '$percent%',
                onChanged: (_) {},
                onChangeEnd: (v) async {
                  final dio = ref.read(dioClientProvider);
                  await dio.patch(
                      ApiEndpoints.scheduleTask(
                          task['id'] as String),
                      data: {
                        'percent_complete': v.toInt(),
                        'status': v >= 100
                            ? 'complete'
                            : v > 0
                                ? 'in_progress'
                                : 'not_started',
                      });
                  onRefresh();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
