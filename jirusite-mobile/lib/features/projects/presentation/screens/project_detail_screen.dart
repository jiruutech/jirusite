// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../shared_widgets/cost_code_variance_row.dart';
import '../../../../shared_widgets/empty_state.dart';
import '../../../../shared_widgets/level_widget.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _projectDashboardProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, projectId) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.projectDashboard(projectId));
  return resp.data as Map<String, dynamic>;
});

/// Local spent for the project (expenses + labour from SQLite)
final _localSpentProvider = FutureProvider.autoDispose
    .family<double, String>((ref, projectId) =>
        ref.read(appDatabaseProvider).getProjectTotalSpent(projectId));

// ── Screen ────────────────────────────────────────────────────────────────────

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_projectDashboardProvider(projectId));
    final localSpent = ref.watch(_localSpentProvider(projectId)).valueOrNull;

    return dashAsync.when(
      loading: () => _ProjectDetailSkeleton(projectId: projectId),
      error: (e, _) => Scaffold(
        appBar: _ProjectAppBar(projectName: 'Project', projectId: projectId),
        body: ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_projectDashboardProvider(projectId)),
        ),
      ),
      data: (data) {
        final name = data['name'] as String? ??
            (data['budget'] as Map?)?['project_name'] as String? ??
            'Project';
        // Merge local spent into the budget map if server didn't provide it
        final enriched = Map<String, dynamic>.from(data);
        if (localSpent != null && localSpent > 0) {
          final budget = Map<String, dynamic>.from(
              enriched['budget'] as Map<String, dynamic>? ?? {});
          budget['total_spent'] ??= localSpent;
          enriched['budget'] = budget;
        }
        return _ProjectDetailLoaded(
          projectId: projectId,
          projectName: name,
          data: enriched,
        );
      },
    );
  }
}

// ── Loaded state ──────────────────────────────────────────────────────────────

class _ProjectDetailLoaded extends StatelessWidget {
  const _ProjectDetailLoaded({
    required this.projectId,
    required this.projectName,
    required this.data,
  });

  final String projectId;
  final String projectName;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // DefaultTabController must live INSIDE NestedScrollView's builder,
    // not wrapping it — otherwise SliverPersistentHeader gets null geometry.
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: _ProjectAppBar(
        projectName: projectName,
        projectId: projectId,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/projects/$projectId/expenses/new'),
        backgroundColor: AppColors.safetyOrange,
        foregroundColor: AppColors.chalk,
        shape: const CircleBorder(),
        tooltip: l.addExpense,
        child: const Icon(Icons.add, size: 26),
      ),
      body: DefaultTabController(
        length: 6,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
              child: _ProjectHero(data: data),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: const _TabBarDelegate(),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(projectId: projectId, data: data),
              _ExpensesTab(projectId: projectId),
              _LaborTab(projectId: projectId),
              _PlaceholderTab(
                label: l.materials,
                icon: Icons.inventory_2_outlined,
                onAction: () => context.push('/projects/$projectId/expenses'),
              ),
              _PlaceholderTab(
                label: l.schedule,
                icon: Icons.calendar_month_outlined,
                onAction: () => context.push('/projects/$projectId/schedule'),
              ),
              _TeamTab(projectId: projectId, data: data),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _ProjectAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProjectAppBar(
      {required this.projectName, required this.projectId});

  final String projectName;
  final String projectId;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.chalk,
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Back chevron
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppColors.blueprintInk, size: 26),
              onPressed: () => context.pop(),
              tooltip: l.back,
            ),
            Expanded(
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.blueprintInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero: full Level Widget ────────────────────────────────────────────────────

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = data['budget'] as Map<String, dynamic>? ?? {};
    final totalBudget = parseDouble(budget['total_budget']);
    final totalSpent = parseDoubleOrZero(budget['total_spent']);

    final variance = totalBudget != null && totalBudget > 0
        ? (totalSpent - totalBudget) / totalBudget * 100
        : 0.0;
    final varianceLabel =
        '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(1)}%';

    final ratio =
        totalBudget != null && totalBudget > 0 ? totalSpent / totalBudget : 0.0;
    final varianceColor = ratio < 0.85
        ? AppColors.levelGreen
        : ratio <= 1.0
            ? AppColors.ochreDust
            : AppColors.rebarRust;

    final statusLine = ratio > 1.0
        ? l.trendingOverBudget
        : ratio > 0.85
            ? l.approachingBudgetLimit
            : l.onTrack;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.chalk,
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Full-width Level Widget — the one moment of breathing room
          LevelWidget(
            budget: totalBudget,
            spent: totalSpent,
            showLabel: false,
            height: 40,
          ),
          const SizedBox(height: 12),

          // Large variance % — IBM Plex Mono, colour-matched to zone
          if (totalBudget != null && totalBudget > 0) ...[
            Text(
              varianceLabel,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: varianceColor,
                fontFamily: 'monospace',
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Plain-language status — editorial, not raw data
          Text(
            statusLine,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          // Budget summary row
          if (totalBudget != null && totalBudget > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroStat(
                  label: l.budget,
                  value: formatEtb(totalBudget),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  width: 0.5,
                  height: 28,
                  color: AppColors.concrete,
                ),
                _HeroStat(
                  label: l.spent,
                  value: formatEtb(totalSpent),
                  valueColor: varianceColor,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  width: 0.5,
                  height: 28,
                  color: AppColors.concrete,
                ),
                _HeroStat(
                  label: l.remaining,
                  value: formatEtb(
                      (totalBudget - totalSpent).abs()),
                  valueColor: totalSpent > totalBudget
                      ? AppColors.rebarRust
                      : AppColors.textPrimary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.numeric.copyWith(
            fontSize: 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Tab bar delegate ───────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate();

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.chalk,
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.safetyOrange,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: AppColors.safetyOrange,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        tabs: [
          Tab(text: l.overview),
          Tab(text: l.expenses),
          Tab(text: l.labour),
          Tab(text: l.materials),
          Tab(text: l.schedule),
          Tab(text: l.team),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.projectId, required this.data});
  final String projectId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final costCodes = (data['costCodes'] as List?)
            ?.cast<Map<String, dynamic>>()
        ?? [];
    final recent = (data['recentExpenses'] as List?)
            ?.cast<Map<String, dynamic>>()
        ?? [];
    final budget = data['budget'] as Map<String, dynamic>? ?? {};

    // Sort cost codes by variance (largest overspend first) — this ordering
    // is the key product decision that makes the screen feel intelligent.
    final sorted = [...costCodes];
    sorted.sort((a, b) {
      final aVar = _variance(a);
      final bVar = _variance(b);
      return bVar.compareTo(aVar);
    });

    // Quick stats
    final targetEnd = budget['target_end_date'] as String?;
    final daysRemaining = _daysRemaining(targetEnd);
    final schedPct = parseDouble(budget['schedule_complete_pct']);
    final pendingSync = (data['pendingSyncCount'] as int?) ?? 0;

    return CustomScrollView(
      slivers: [
        // ── Cost-code breakdown ─────────────────────────────────────────
        if (sorted.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: l.budgetByCostCode,
              trailing: l.sortedByVariance,
            ),
          ),
          SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final cc = sorted[i];
              final budgeted =
                  parseDoubleOrZero(cc['budgeted_amount']);
              final spent = parseDoubleOrZero(cc['spent']);
              return CostCodeVarianceRow(
                name: cc['name'] as String? ?? '—',
                budgeted: budgeted,
                spent: spent,
                showDivider: i < sorted.length - 1,
              );
            },
          ),
        ],

        // ── Recent activity ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionLabel(label: l.recentActivity),
        ),
        if (recent.isEmpty)
          const SliverToBoxAdapter(
            child: _EmptyActivityRow(),
          )
        else
          SliverList.builder(
            itemCount: recent.take(8).length,
            itemBuilder: (_, i) {
              final item = recent[i];
              return _ActivityRow(entry: item);
            },
          ),

        // See all link
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () =>
                    context.push('/projects/$projectId/expenses'),
                child: Text(
                  l.seeAllActivity,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.safetyOrange,
                  ),
                ),
              ),
            ),
          ),

        // ── Quick stats footer ──────────────────────────────────────────
        if (daysRemaining != null ||
            schedPct != null ||
            pendingSync > 0)
          SliverToBoxAdapter(
            child: _QuickStatsFooter(
              daysRemaining: daysRemaining,
              schedPct: schedPct,
              pendingSync: pendingSync,
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  double _variance(Map<String, dynamic> cc) {
    final budgeted = parseDoubleOrZero(cc['budgeted_amount']);
    final spent = parseDoubleOrZero(cc['spent']);
    if (budgeted <= 0) return 0;
    return (spent - budgeted) / budgeted;
  }

  int? _daysRemaining(String? targetEnd) {
    if (targetEnd == null) return null;
    final end = DateTime.tryParse(targetEnd);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Activity row ──────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final type = entry['expense_type'] as String? ?? '';
    final description = entry['description'] as String? ?? type;
    final amount = parseDouble(entry['amount']);
    final createdAt = DateTime.tryParse(
        entry['created_at'] as String? ?? '');
    final relTime = createdAt != null ? _relativeTime(context, createdAt) : '';

    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _typeColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(_typeIcon(type),
                color: _typeColor(type), size: 14),
          ),
          const SizedBox(width: 10),

          // Description
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Amount + time
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatEtb(amount),
                style: AppTextStyles.numeric.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                relTime,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final l = AppLocalizations.of(context);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    return l.weeksAgo((diff.inDays / 7).floor());
  }

  Color _typeColor(String type) => switch (type) {
        'material' => AppColors.blueprintInk,
        'labor' => AppColors.levelGreen,
        'equipment' => AppColors.ochreDust,
        _ => AppColors.textSecondary,
      };

  IconData _typeIcon(String type) => switch (type) {
        'material' => Icons.inventory_2_outlined,
        'labor' => Icons.people_outlined,
        'equipment' => Icons.build_outlined,
        _ => Icons.receipt_outlined,
      };
}

class _EmptyActivityRow extends StatelessWidget {
  const _EmptyActivityRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(
        l.noRecentActivity,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Quick stats footer ────────────────────────────────────────────────────────

class _QuickStatsFooter extends StatelessWidget {
  const _QuickStatsFooter({
    this.daysRemaining,
    this.schedPct,
    required this.pendingSync,
  });
  final int? daysRemaining;
  final double? schedPct;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (daysRemaining != null)
            _FooterStat(
              label: l.daysLeft,
              value: '$daysRemaining',
            ),
          if (schedPct != null) ...[
            if (daysRemaining != null) const _FooterDivider(),
            _FooterStat(
              label: l.schedulePercentage,
              value: '${schedPct!.toStringAsFixed(0)}%',
            ),
          ],
          if (pendingSync > 0) ...[
            if (daysRemaining != null || schedPct != null)
              const _FooterDivider(),
            _FooterStat(
              label: l.pendingSyncCount,
              value: '$pendingSync',
              valueColor: AppColors.ochreDust,
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat(
      {required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.numeric.copyWith(
            fontSize: 13,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        width: 0.5,
        height: 24,
        color: AppColors.concrete,
      );
}

// ── Placeholder tabs ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label, required this.icon, required this.onAction});
  final String label;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            child: Text(l.viewTab(label)),
          ),
        ],
      ),
    );
  }
}

// ── Expenses tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final expensesAsync = ref.watch(
      StreamProvider.autoDispose((ref) =>
          ref.read(appDatabaseProvider).watchExpenses(projectId)),
    );

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (expenses) {
        if (expenses.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: l.noExpensesYet,
            actionLabel: l.addExpense,
            onAction: () => context.push('/projects/$projectId/expenses/new'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: expenses.length,
          itemBuilder: (_, i) {
            final e = expenses[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _expenseColor(e.expenseType).withValues(alpha: 0.1),
                  child: Icon(_expenseIcon(e.expenseType),
                      color: _expenseColor(e.expenseType), size: 18),
                ),
                title: Text(e.description ?? e.expenseType,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(e.transactionDate,
                    style: Theme.of(context).textTheme.bodySmall),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatEtb(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(e.syncStatus == 'pending' ? '⏳' : '✓',
                        style: TextStyle(fontSize: 10,
                            color: e.syncStatus == 'pending'
                                ? AppColors.syncPending
                                : AppColors.syncSynced)),
                  ],
                ),
                onTap: () => context.push('/projects/$projectId/expenses/new'),
              ),
            );
          },
        );
      },
    );
  }

  Color _expenseColor(String type) => switch (type) {
    'material' => AppColors.blueprintInk,
    'labor' => AppColors.levelGreen,
    'equipment' => AppColors.safetyOrange,
    _ => AppColors.textSecondary,
  };

  IconData _expenseIcon(String type) => switch (type) {
    'material' => Icons.inventory_2_outlined,
    'labor' => Icons.people_outlined,
    'equipment' => Icons.build_outlined,
    _ => Icons.receipt_outlined,
  };
}

// ── Labour tab ────────────────────────────────────────────────────────────────

class _LaborTab extends ConsumerWidget {
  const _LaborTab({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final laborAsync = ref.watch(
      StreamProvider.autoDispose((ref) =>
          ref.read(appDatabaseProvider).watchLabor(projectId)),
    );

    return laborAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.people_outlined,
            title: l.noLaborEntriesYet,
            actionLabel: l.addLaborEntry,
            onAction: () => context.push('/projects/$projectId/labor/new'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A9C27B0),
                  child: Icon(Icons.people_outlined, color: Colors.purple, size: 20),
                ),
                title: Text(e.workerOrCrewName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${e.numberOfWorkers} ${l.workersCount} · ${e.workDate}',
                    style: Theme.of(context).textTheme.bodySmall),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatEtb(e.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(e.syncStatus == 'pending' ? '⏳' : '✓',
                        style: TextStyle(fontSize: 10,
                            color: e.syncStatus == 'pending'
                                ? AppColors.syncPending
                                : AppColors.syncSynced)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Team tab ──────────────────────────────────────────────────────────────────

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.projectId, required this.data});
  final String projectId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final team = (data['team'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (team.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: l.teamMembers,
        subtitle: l.inviteMember,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: team.length,
      itemBuilder: (_, i) {
        final member = team[i];
        final name = member['full_name'] as String? ?? '—';
        final role = member['role'] as String? ?? 'viewer';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(name),
          subtitle: Text(role, style: Theme.of(context).textTheme.bodySmall),
        );
      },
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ProjectDetailSkeleton extends StatelessWidget {
  const _ProjectDetailSkeleton({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: _ProjectAppBar(
          projectName: l.loadingEllipsis, projectId: projectId),
      body: Column(
        children: [
          // Hero skeleton
          Container(
            height: 180,
            margin: const EdgeInsets.all(0),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              color: AppColors.chalk,
              border: Border(
                bottom: BorderSide(color: AppColors.concrete, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.concrete.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 28,
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.concrete.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.concrete.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          // Tab bar skeleton
          Container(
            height: 44,
            color: AppColors.chalk,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 64,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.concrete.withValues(alpha: i == 0 ? 0.4 : 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          // Row skeletons
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, i) => Container(
                height: 56,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.concrete, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.concrete
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.concrete
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.concrete
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
