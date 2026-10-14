import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/currency.dart';
import '../../../../shared_widgets/empty_state.dart';

class LaborListScreen extends ConsumerWidget {
  const LaborListScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laborAsync = ref.watch(
      StreamProvider.autoDispose(
          (ref) => ref.read(appDatabaseProvider).watchLabor(projectId)),
    );
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.laborEntriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/labor/new'),
        icon: const Icon(Icons.add),
        label: Text(l.addLabor),
      ),
      body: laborAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.people_outlined,
              title: l.noLaborEntriesYet,
              actionLabel: l.addLaborEntry,
              onAction: () =>
                  context.push('/projects/$projectId/labor/new'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (_, i) =>
                _LaborTile(entry: entries[i], projectId: projectId),
          );
        },
      ),
    );
  }
}

class _LaborTile extends ConsumerWidget {
  const _LaborTile({required this.entry, required this.projectId});
  final LocalLaborEntry entry;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.rebarRust,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) => _confirmDelete(context, l),
      onDismissed: (_) => _delete(context, ref, l),
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref, l),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1A9C27B0),
              child: Icon(Icons.people_outlined,
                  color: Colors.purple, size: 20),
            ),
            title: Text(entry.workerOrCrewName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${entry.numberOfWorkers} ${l.workersCount} · ${entry.workDate}',
                style: Theme.of(context).textTheme.bodySmall),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatEtb(entry.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  entry.syncStatus == 'pending' ? '⏳' : '✓',
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.syncStatus == 'pending'
                        ? AppColors.syncPending
                        : AppColors.syncSynced,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, AppLocalizations l) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.deleteLabor),
            content: Text(l.deleteConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(l.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    await ref.read(appDatabaseProvider).deleteLabor(entry.id);
    if (entry.serverId != null) {
      try {
        final dio = ref.read(dioClientProvider);
        await dio.delete(
            ApiEndpoints.deleteLaborEndpoint(entry.serverId!));
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.laborDeleted),
          backgroundColor: AppColors.levelGreen));
    }
  }

  void _showActions(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.editLabor),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context, ref, l);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: Text(l.deleteLabor,
                  style: const TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete(context, l);
                if (confirmed && context.mounted) {
                  await _delete(context, ref, l);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final nameCtrl =
        TextEditingController(text: entry.workerOrCrewName);
    final amountCtrl =
        TextEditingController(text: entry.totalAmount.toStringAsFixed(2));
    final descCtrl =
        TextEditingController(text: entry.workDescription ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.editLabor,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.workerCrewNameRequired,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: l.totalAmountEtb,
                    prefixText: 'ETB  ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l.workDescriptionLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updated = LocalLaborEntry(
                        id: entry.id,
                        projectId: entry.projectId,
                        costCodeId: entry.costCodeId,
                        enteredBy: entry.enteredBy,
                        workerOrCrewName: nameCtrl.text.trim().isNotEmpty
                            ? nameCtrl.text.trim()
                            : entry.workerOrCrewName,
                        workDescription:
                            descCtrl.text.trim().isNotEmpty
                                ? descCtrl.text.trim()
                                : null,
                        numberOfWorkers: entry.numberOfWorkers,
                        dailyRate: entry.dailyRate,
                        totalAmount:
                            double.tryParse(amountCtrl.text) ??
                                entry.totalAmount,
                        workDate: entry.workDate,
                        syncStatus: 'pending',
                        serverId: entry.serverId,
                        createdAt: entry.createdAt,
                      );
                      await ref
                          .read(appDatabaseProvider)
                          .updateLabor(updated);
                      ref.read(syncEngineProvider).sync().ignore();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(l.laborUpdated),
                          backgroundColor: AppColors.levelGreen,
                        ));
                      }
                    },
                    child: Text(l.save),
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
