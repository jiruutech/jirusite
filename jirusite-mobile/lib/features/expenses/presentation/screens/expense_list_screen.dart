import 'dart:convert';

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

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(
      StreamProvider.autoDispose((ref) =>
          ref.read(appDatabaseProvider).watchExpenses(projectId)),
    );
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(title: Text(l.expenses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/expenses/new'),
        icon: const Icon(Icons.add),
        label: Text(l.addExpense),
        backgroundColor: AppColors.safetyOrange,
        foregroundColor: Colors.white,
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (expenses) {
          if (expenses.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l.noExpensesYet,
              actionLabel: l.addExpense,
              onAction: () =>
                  context.push('/projects/$projectId/expenses/new'),
            );
          }

          // Group by type for summary
          final totalAmount =
              expenses.fold<double>(0, (s, e) => s + e.amount);
          final pendingCount =
              expenses.where((e) => e.syncStatus == 'pending').length;

          return CustomScrollView(
            slivers: [
              // Summary header
              SliverToBoxAdapter(
                child: _ExpenseSummaryCard(
                  total: totalAmount,
                  count: expenses.length,
                  pending: pendingCount,
                  expenses: expenses,
                ),
              ),
              // List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ExpenseCard(
                    expense: expenses[i],
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

class _ExpenseSummaryCard extends StatelessWidget {
  const _ExpenseSummaryCard({
    required this.total,
    required this.count,
    required this.pending,
    required this.expenses,
  });
  final double total;
  final int count;
  final int pending;
  final List<LocalExpense> expenses;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // By type breakdown
    final byType = <String, double>{};
    for (final e in expenses) {
      byType[e.expenseType] = (byType[e.expenseType] ?? 0) + e.amount;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blueprintInk, Color(0xFF2A4A5A)],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.totalSpent,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(formatEtb(total),
                      style: AppTextStyles.numeric.copyWith(
                          fontSize: 22, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DarkPill(
                      label:
                          '$count ${l.expenses.toLowerCase()}'),
                  if (pending > 0) ...[
                    const SizedBox(height: 4),
                    _DarkPill(
                        label: '$pending pending',
                        color: AppColors.ochreDust),
                  ],
                ],
              ),
            ],
          ),
          if (byType.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: byType.entries.map((e) {
                final color = _typeColor(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(e.key), size: 12, color: color),
                      const SizedBox(width: 5),
                      Text(
                        '${e.key}: ${formatEtbCompact(e.value)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'material' => AppColors.levelGreen,
        'labor' => const Color(0xFF9C27B0),
        'equipment' => AppColors.safetyOrange,
        _ => AppColors.ochreDust,
      };

  IconData _typeIcon(String type) => switch (type) {
        'material' => Icons.inventory_2_outlined,
        'labor' => Icons.people_outlined,
        'equipment' => Icons.build_outlined,
        _ => Icons.receipt_outlined,
      };
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label, this.color});
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

// ── Expense card ──────────────────────────────────────────────────────────────

class _ExpenseCard extends ConsumerWidget {
  const _ExpenseCard(
      {required this.expense, required this.projectId});
  final LocalExpense expense;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final color = _typeColor;

    return Dismissible(
      key: ValueKey(expense.id),
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
          child: Row(
            children: [
              // Left color accent
              Container(
                width: 5,
                height: 70,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description ?? expense.expenseType,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(expense.transactionDate,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        if (expense.costCodeId != null) ...[
                          const Text(' · ',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                          const Icon(Icons.label_outline,
                              size: 11,
                              color: AppColors.textSecondary),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              // Amount + sync
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatEtb(expense.amount),
                      style: AppTextStyles.numeric.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueprintInk),
                    ),
                    const SizedBox(height: 4),
                    _SyncChip(
                      syncStatus: expense.syncStatus,
                      onConflictTap: expense.syncStatus == 'conflict'
                          ? () =>
                              _showConflictDialog(context, ref, l)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
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
            title: Text(l.deleteExpense),
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
    await ref.read(appDatabaseProvider).deleteExpense(expense.id);
    if (expense.serverId != null) {
      try {
        final dio = ref.read(dioClientProvider);
        await dio.delete(
            ApiEndpoints.deleteExpenseEndpoint(expense.serverId!));
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.expenseDeleted),
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
              title: Text(l.editExpense),
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
              title: Text(l.deleteExpense,
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
    final amountCtrl = TextEditingController(
        text: expense.amount.toStringAsFixed(2));
    final descCtrl =
        TextEditingController(text: expense.description ?? '');

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
                  decoration: BoxDecoration(
                      color: AppColors.concrete,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.editExpense,
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: l.amountRequired,
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
                    labelText: l.description,
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
                      backgroundColor: AppColors.safetyOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final newAmount =
                          double.tryParse(amountCtrl.text) ??
                              expense.amount;
                      final updated = LocalExpense(
                        id: expense.id,
                        projectId: expense.projectId,
                        costCodeId: expense.costCodeId,
                        enteredBy: expense.enteredBy,
                        supplierId: expense.supplierId,
                        description:
                            descCtrl.text.trim().isNotEmpty
                                ? descCtrl.text.trim()
                                : null,
                        amount: newAmount,
                        quantity: expense.quantity,
                        unit: expense.unit,
                        expenseType: expense.expenseType,
                        receiptPhotoUrl: expense.receiptPhotoUrl,
                        receiptPhotoLocalPath:
                            expense.receiptPhotoLocalPath,
                        transactionDate: expense.transactionDate,
                        syncStatus: 'pending',
                        serverId: expense.serverId,
                        createdAt: expense.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      await ref
                          .read(appDatabaseProvider)
                          .updateExpense(updated);
                      ref.read(syncEngineProvider).sync().ignore();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(l.expenseUpdated),
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

  void _showConflictDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    Map<String, dynamic>? serverData;
    try {
      if (expense.conflictPayload != null) {
        serverData =
            jsonDecode(expense.conflictPayload!) as Map<String, dynamic>;
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.conflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.conflictBody,
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _ConflictBox(
              label: l.myVersion,
              amount: expense.amount,
              description: expense.description,
              color: AppColors.blueprintInk,
            ),
            const SizedBox(height: 8),
            if (serverData != null)
              _ConflictBox(
                label: l.serverVersion,
                amount:
                    (serverData['amount'] as num?)?.toDouble() ?? 0,
                description:
                    serverData['description'] as String?,
                color: AppColors.ochreDust,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final updated = LocalExpense(
                id: expense.id,
                projectId: expense.projectId,
                costCodeId: expense.costCodeId,
                enteredBy: expense.enteredBy,
                supplierId: expense.supplierId,
                description: expense.description,
                amount: expense.amount,
                quantity: expense.quantity,
                unit: expense.unit,
                expenseType: expense.expenseType,
                receiptPhotoUrl: expense.receiptPhotoUrl,
                receiptPhotoLocalPath:
                    expense.receiptPhotoLocalPath,
                transactionDate: expense.transactionDate,
                syncStatus: 'pending',
                serverId: expense.serverId,
                conflictPayload: null,
                createdAt: expense.createdAt,
                updatedAt: DateTime.now(),
              );
              await ref
                  .read(appDatabaseProvider)
                  .updateExpense(updated);
              ref.read(syncEngineProvider).sync().ignore();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(l.conflictResolved),
                    backgroundColor: AppColors.levelGreen));
              }
            },
            child: Text(l.keepMine),
          ),
          ElevatedButton(
            onPressed: () async {
              if (serverData != null) {
                final s = LocalExpense(
                  id: expense.id,
                  projectId: expense.projectId,
                  costCodeId:
                      serverData['cost_code_id'] as String?,
                  enteredBy: expense.enteredBy,
                  supplierId:
                      serverData['supplier_id'] as String?,
                  description:
                      serverData['description'] as String?,
                  amount:
                      (serverData['amount'] as num).toDouble(),
                  quantity:
                      (serverData['quantity'] as num?)?.toDouble(),
                  unit: serverData['unit'] as String?,
                  expenseType:
                      serverData['expense_type'] as String? ??
                          expense.expenseType,
                  receiptPhotoUrl:
                      serverData['receipt_photo_url'] as String?,
                  transactionDate:
                      serverData['transaction_date'] as String? ??
                          expense.transactionDate,
                  syncStatus: 'synced',
                  serverId: expense.serverId,
                  conflictPayload: null,
                  createdAt: expense.createdAt,
                  updatedAt: DateTime.now(),
                );
                await ref.read(appDatabaseProvider).updateExpense(s);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(l.conflictResolved),
                    backgroundColor: AppColors.levelGreen));
              }
            },
            child: Text(l.useServer),
          ),
        ],
      ),
    );
  }

  Color get _typeColor => switch (expense.expenseType) {
        'material' => AppColors.levelGreen,
        'labor' => const Color(0xFF9C27B0),
        'equipment' => AppColors.safetyOrange,
        _ => AppColors.ochreDust,
      };

  IconData get _icon => switch (expense.expenseType) {
        'material' => Icons.inventory_2_outlined,
        'labor' => Icons.people_outlined,
        'equipment' => Icons.build_outlined,
        _ => Icons.receipt_outlined,
      };
}

class _ConflictBox extends StatelessWidget {
  const _ConflictBox(
      {required this.label,
      required this.amount,
      this.description,
      required this.color});
  final String label;
  final double amount;
  final String? description;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  if (description != null)
                    Text(description!,
                        style:
                            const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(formatEtb(amount),
                style: AppTextStyles.numeric
                    .copyWith(fontSize: 13, color: color)),
          ],
        ),
      );
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.syncStatus, this.onConflictTap});
  final String? syncStatus;
  final VoidCallback? onConflictTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = switch (syncStatus) {
      'pending' => AppColors.ochreDust,
      'conflict' => AppColors.rebarRust,
      _ => AppColors.levelGreen,
    };
    final label = switch (syncStatus) {
      'pending' => '⏳',
      'conflict' => '⚠',
      _ => '✓',
    };
    final tooltip = switch (syncStatus) {
      'pending' => l.pendingSync,
      'conflict' => l.syncConflict,
      _ => l.synced,
    };

    return GestureDetector(
      onTap: syncStatus == 'conflict' ? onConflictTap : null,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
