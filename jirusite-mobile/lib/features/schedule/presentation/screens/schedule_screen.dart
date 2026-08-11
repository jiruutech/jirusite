import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
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
    final scheduleAsync = ref.watch(_scheduleProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No tasks scheduled yet',
            );
          }
          // Group by cost code
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final t in tasks) {
            final key = t['cost_code_name'] as String? ?? 'General';
            grouped.putIfAbsent(key, () => []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: grouped.entries.map((e) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(e.key, style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.primary)),
                ),
                ...e.value.map((t) => _TaskCard(task: t, projectId: projectId)),
              ],
            )).toList(),
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Task'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Task Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final dio = ref.read(dioClientProvider);
              await dio.post(ApiEndpoints.projectSchedule(projectId), data: {
                'name': nameCtrl.text.trim(),
              });
              ref.invalidate(_scheduleProvider(projectId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.projectId});
  final Map<String, dynamic> task;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = task['status'] as String? ?? 'not_started';
    final percent = task['percent_complete'] as int? ?? 0;
    final color = switch (status) {
      'complete'    => AppColors.success,
      'in_progress' => AppColors.primary,
      'delayed'     => AppColors.error,
      _             => AppColors.textSecondary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(task['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$percent% complete', style: Theme.of(context).textTheme.bodySmall),
                if (task['planned_start'] != null || task['planned_end'] != null)
                  Text(
                    '${task['planned_start'] ?? '?'} → ${task['planned_end'] ?? '?'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: percent.toDouble(),
                    min: 0, max: 100, divisions: 20,
                    label: '$percent%',
                    activeColor: color,
                    onChangeEnd: (v) async {
                      final dio = ref.read(dioClientProvider);
                      await dio.patch(ApiEndpoints.scheduleTask(task['id'] as String), data: {
                        'percent_complete': v.toInt(),
                        'status': v >= 100 ? 'complete' : v > 0 ? 'in_progress' : 'not_started',
                      });
                      ref.invalidate(_scheduleProvider(projectId));
                    },
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
