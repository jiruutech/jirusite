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
import '../../../../shared_widgets/status_stripe_card.dart';

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
      appBar: AppBar(title: Text(l.expenses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/expenses/new'),
        icon: const Icon(Icons.add),
        label: Text(l.addExpense),
        backgroundColor: AppColors.safetyOrange,
        foregroundColor: AppColors.chalk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: expenses.length,
            itemBuilder: (_, i) => _ExpenseTile(
              expense: expenses[i],
              projectId: projectId,
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense, required this.projectId});
  final LocalExpense expense;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.rebarRust,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) => _confirmDelete(context, l),
      onDismissed: (_) => _delete(context, ref, l),
      child: GestureDetector(
        onLongPress: () => _showActions(context, ref, l),
        child: StatusStripeCard(
          stripeColor: _stripeColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _stripeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(_icon, color: _stripeColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description ?? expense.expenseType,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(expense.transactionDate,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatEtb(expense.amount),
                      style: AppTextStyles.numeric.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    _SyncDot(
                      syncStatus: expense.syncStatus,
                      onConflictTap: expense.syncStatus == 'conflict'
                          ? () => _showConflictDialog(context, ref, l)
                          : null,
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

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<bool> _confirmDelete(BuildContext context, AppLocalizations l) async {
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
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(l.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteExpense(expense.id);
    // Best-effort server delete (if already synced, has serverId)
    if (expense.serverId != null) {
      try {
        final dio = ref.read(dioClientProvider);
        await dio.delete(ApiEndpoints.deleteExpenseEndpoint(expense.serverId!));
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l.expenseDeleted),
            backgroundColor: AppColors.levelGreen),
      );
    }
  }

  // ── Long press actions (edit) ────────────────────────────────────────────

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
              title: Text(l.editExpense),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(context, ref, l);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: Text(l.deleteExpense,
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
    final amountCtrl =
        TextEditingController(text: expense.amount.toStringAsFixed(2));
    final descCtrl =
        TextEditingController(text: expense.description ?? '');

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
                Text(l.editExpense,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: l.amountRequired,
                    prefixText: 'ETB  ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: l.description,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                        description: descCtrl.text.trim().isNotEmpty
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

  // ── Conflict resolution ──────────────────────────────────────────────────

  void _showConflictDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    Map<String, dynamic>? serverData;
    try {
      if (expense.conflictPayload != null) {
        serverData = jsonDecode(expense.conflictPayload!)
            as Map<String, dynamic>;
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.conflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.conflictBody,
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _ConflictRow(
              label: l.myVersion,
              amount: expense.amount,
              description: expense.description,
              color: AppColors.blueprintInk,
            ),
            const SizedBox(height: 8),
            if (serverData != null)
              _ConflictRow(
                label: l.serverVersion,
                amount: (serverData['amount'] as num?)?.toDouble() ?? 0,
                description: serverData['description'] as String?,
                color: AppColors.ochreDust,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Keep local — re-mark as pending so next sync pushes it
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
                receiptPhotoLocalPath: expense.receiptPhotoLocalPath,
                transactionDate: expense.transactionDate,
                syncStatus: 'pending',
                serverId: expense.serverId,
                conflictPayload: null,
                createdAt: expense.createdAt,
                updatedAt: DateTime.now(),
              );
              await ref.read(appDatabaseProvider).updateExpense(updated);
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
              // Use server version — overwrite local with server data
              if (serverData != null) {
                final serverExpense = LocalExpense(
                  id: expense.id,
                  projectId: expense.projectId,
                  costCodeId: serverData['cost_code_id'] as String?,
                  enteredBy: expense.enteredBy,
                  supplierId: serverData['supplier_id'] as String?,
                  description: serverData['description'] as String?,
                  amount: (serverData['amount'] as num).toDouble(),
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
                await ref
                    .read(appDatabaseProvider)
                    .updateExpense(serverExpense);
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

  Color get _stripeColor => switch (expense.expenseType) {
        'material' => AppColors.blueprintInk,
        'labor' => AppColors.levelGreen,
        'equipment' => AppColors.safetyOrange,
        _ => AppColors.concrete,
      };

  IconData get _icon => switch (expense.expenseType) {
        'material' => Icons.inventory_2_outlined,
        'labor' => Icons.people_outlined,
        'equipment' => Icons.build_outlined,
        _ => Icons.receipt_outlined,
      };
}

// ── Conflict comparison row ────────────────────────────────────────────────

class _ConflictRow extends StatelessWidget {
  const _ConflictRow(
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
          borderRadius: BorderRadius.circular(6),
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
                          fontWeight: FontWeight.w600,
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

// ── Sync status dot ────────────────────────────────────────────────────────

class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.syncStatus, this.onConflictTap});
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

    final tooltip = switch (syncStatus) {
      'pending' => l.pendingSync,
      'conflict' => l.syncConflict,
      _ => l.synced,
    };

    final dot = Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );

    if (syncStatus == 'conflict' && onConflictTap != null) {
      return GestureDetector(
        onTap: onConflictTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 3),
            const Icon(Icons.warning_amber_rounded,
                size: 12, color: AppColors.rebarRust),
          ],
        ),
      );
    }
    return dot;
  }
}
