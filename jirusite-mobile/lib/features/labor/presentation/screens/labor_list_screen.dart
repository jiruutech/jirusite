import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency.dart';
import '../../../../shared_widgets/empty_state.dart';

class LaborListScreen extends ConsumerWidget {
  const LaborListScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laborAsync = ref.watch(
      StreamProvider.autoDispose((ref) =>
          ref.read(appDatabaseProvider).watchLabor(projectId)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Labor Entries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/labor/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Labor'),
      ),
      body: laborAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.people_outlined,
              title: 'No labor entries yet',
              actionLabel: 'Add Labor Entry',
              onAction: () => context.push('/projects/$projectId/labor/new'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (_, i) => _LaborTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _LaborTile extends StatelessWidget {
  const _LaborTile({required this.entry});
  final LocalLaborEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A9C27B0),
          child: Icon(Icons.people_outlined, color: Colors.purple, size: 20),
        ),
        title: Text(entry.workerOrCrewName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${entry.numberOfWorkers} workers · ${entry.workDate}',
            style: Theme.of(context).textTheme.bodySmall),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatEtb(entry.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(entry.syncStatus == 'pending' ? '⏳' : '✓',
                style: TextStyle(
                  fontSize: 10,
                  color: entry.syncStatus == 'pending'
                      ? AppColors.syncPending
                      : AppColors.syncSynced,
                )),
          ],
        ),
      ),
    );
  }
}
