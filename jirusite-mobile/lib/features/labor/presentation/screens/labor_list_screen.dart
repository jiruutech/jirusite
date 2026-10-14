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
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(title: Text(l.laborEntriesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/labor/new'),
        icon: const Icon(Icons.add),
        label: Text(l.addLabor),
        backgroundColor: AppColors.levelGreen,
        foregroundColor: Colors.white,
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

          final totalAmount =
              entries.fold<double>(0, (s, e) => s + e.totalAmount);
          final totalWorkers = entries.fold<int>(
              0, (s, e) => s + e.numberOfWorkers);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _LaborSummaryCard(
                  total: totalAmount,
                  entries: entries.length,
                  workers: totalWorkers,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LaborCard(
                    entry: entries[i],
                    projectId: projectId,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _LaborSummaryCard extends StatelessWidget {
  const _LaborSummaryCard({
    required this.total,
    required this.entries,
    required this.workers,
  });
  final double total;
  final int entries;
  final int workers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.totalAmount,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 4),
                Text(formatEtb(total),
                    style: AppTextStyles.numeric
                        .copyWith(fontSize: 22, color: Colors.white)),
              ],
            ),
          ),
          Column(
            children: [
              _DarkPill(label: '$entries entries'),
              const SizedBox(height: 4),
              _DarkPill(label: '$workers ${l.workersCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      );
}

// ── Labor card ────────────────────────────────────────────────────────────────

class _LaborCard extends ConsumerWidget {
  const _LaborCard({required this.entry, required this.projectId});
  final LocalLaborEntry entry;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isPending = entry.syncStatus == 'pending';

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.rebarRust,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text('Delete',
                style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context, l),
      onDismissed: (_) => _delete(context, ref, l),
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref, l),
        child: Container(
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
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_outlined,
                      color: Color(0xFF9C27B0), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.workerOrCrewName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.group_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                            '${entry.numberOfWorkers} ${l.workersCount}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(entry.workDate,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ]),
                      if (entry.workDescription != null) ...[
                        const SizedBox(height: 3),
                        Text(entry.workDescription!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatEtb(entry.totalAmount),
                      style: AppTextStyles.numeric.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9C27B0)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPending
                                ? AppColors.ochreDust
                                : AppColors.levelGreen)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPending ? '⏳' : '✓',
                        style: TextStyle(
                            fontSize: 10,
                            color: isPending
                                ? AppColors.ochreDust
                                : AppColors.levelGreen,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
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
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4, margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: AppColors.concrete,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.blueprintInk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.blueprintInk, size: 18),
              ),
              title: Text(l.editLabor),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context, ref, l);
              },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.rebarRust.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline,
                    color: AppColors.rebarRust, size: 18),
              ),
              title: Text(l.deleteLabor,
                  style: const TextStyle(color: AppColors.rebarRust)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete(context, l);
                if (confirmed && context.mounted) {
                  await _delete(context, ref, l);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final nameCtrl =
        TextEditingController(text: entry.workerOrCrewName);
    final amountCtrl = TextEditingController(
        text: entry.totalAmount.toStringAsFixed(2));
    final descCtrl =
        TextEditingController(text: entry.workDescription ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.concrete,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.editLabor,
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.workerCrewNameRequired,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outlined),
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
                    prefixIcon:
                        const Icon(Icons.monetization_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l.workDescriptionLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.levelGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final updated = LocalLaborEntry(
                        id: entry.id,
                        projectId: entry.projectId,
                        costCodeId: entry.costCodeId,
                        enteredBy: entry.enteredBy,
                        workerOrCrewName:
                            nameCtrl.text.trim().isNotEmpty
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
                    child: Text(l.save,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
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
