import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
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
            itemBuilder: (_, i) => _ExpenseTile(expense: expenses[i]),
          );
        },
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final LocalExpense expense;

  @override
  Widget build(BuildContext context) {
    return StatusStripeCard(
      stripeColor: _stripeColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Type icon
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

            // Description + date
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
                  Text(
                    expense.transactionDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + sync dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatEtb(expense.amount),
                  style: AppTextStyles.numeric.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 4),
                _SyncDot(syncStatus: expense.syncStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Left-border stripe color by expense type
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

/// Small coloured dot indicating sync status.
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.syncStatus});
  final String? syncStatus;

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

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
