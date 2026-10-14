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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
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
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.blueprintInk,
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.chalk, size: 20),
              onPressed: () => context.pop(),
              tooltip: l.back,
            ),
            Expanded(
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.chalk,
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

// ── Hero: modern gradient card ────────────────────────────────────────────────

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = data['budget'] as Map<String, dynamic>? ?? {};
    final totalBudget = parseDouble(budget['total_budget']);
    final totalSpent = parseDoubleOrZero(budget['total_spent']);

    final ratio =
        totalBudget != null && totalBudget > 0
            ? (totalSpent / totalBudget).clamp(0.0, 1.0)
            : 0.0;
    final healthColor = ratio < 0.75
        ? AppColors.levelGreen
        : ratio <= 0.9
            ? AppColors.ochreDust
            : AppColors.rebarRust;

    final variance = totalBudget != null && totalBudget > 0
        ? (totalSpent - totalBudget) / totalBudget * 100
        : 0.0;
    final varianceLabel =
        '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(1)}%';

    final statusLine = ratio > 1.0
        ? l.trendingOverBudget
        : ratio > 0.85
            ? l.approachingBudgetLimit
            : l.onTrack;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blueprintInk,
            AppColors.blueprintInk.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.blueprintInk.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: healthColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusLine,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: healthColor)),
                ),
                const Spacer(),
                if (totalBudget != null && totalBudget > 0)
                  Text(varianceLabel,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: healthColor,
                          fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            if (totalBudget != null && totalBudget > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.budget,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                  Text(
                      '${(ratio * 100).toStringAsFixed(0)}% ${l.spent.toLowerCase()}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(healthColor),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3 stat columns
            if (totalBudget != null && totalBudget > 0)
              Row(
                children: [
                  _DarkStat(
                    label: l.budget,
                    value: formatEtbCompact(totalBudget),
                  ),
                  _DarkDivider(),
                  _DarkStat(
                    label: l.spent,
                    value: formatEtbCompact(totalSpent),
                    valueColor: healthColor,
                  ),
                  _DarkDivider(),
                  _DarkStat(
                    label: totalSpent > totalBudget
                        ? 'Over'
                        : l.remaining,
                    value: formatEtbCompact(
                        (totalBudget - totalSpent).abs()),
                    valueColor: totalSpent > totalBudget
                        ? AppColors.rebarRust
                        : AppColors.levelGreen,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(value,
                style: AppTextStyles.numeric.copyWith(
                    fontSize: 14,
                    color: valueColor ?? Colors.white)),
          ],
        ),
      );
}

class _DarkDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 0.5, height: 32,
        color: Colors.white.withValues(alpha: 0.2),
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2))
        ],
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
        indicatorWeight: 2.5,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _typeColor(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(type),
                  color: _typeColor(type), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatEtb(amount),
                  style: AppTextStyles.numeric.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          if (daysRemaining != null)
            _FooterStat(
              label: l.daysLeft,
              value: '$daysRemaining',
              icon: Icons.hourglass_bottom_outlined,
            ),
          if (schedPct != null) ...[
            if (daysRemaining != null) const _FooterDivider(),
            _FooterStat(
              label: l.schedulePercentage,
              value: '${schedPct!.toStringAsFixed(0)}%',
              icon: Icons.timeline_outlined,
            ),
          ],
          if (pendingSync > 0) ...[
            if (daysRemaining != null || schedPct != null)
              const _FooterDivider(),
            _FooterStat(
              label: l.pendingSyncCount,
              value: '$pendingSync',
              valueColor: AppColors.ochreDust,
              icon: Icons.cloud_upload_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat(
      {required this.label, required this.value, this.valueColor, required this.icon});
  final String label;
  final String value;
  final Color? valueColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: valueColor ?? AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.numeric.copyWith(
                  fontSize: 14,
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
          ),
        ],
      ),
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

class _TeamTab extends ConsumerWidget {
  const _TeamTab({required this.projectId, required this.data});
  final String projectId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final team = (data['team'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteSheet(context, ref, l),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l.inviteMember),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: team.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: l.teamMembers,
              subtitle: l.inviteMember,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: team.length,
              itemBuilder: (_, i) {
                final member = team[i];
                final name = member['full_name'] as String? ?? '—';
                final role = member['role_on_project'] as String? ??
                    member['role'] as String? ??
                    'viewer';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name),
                  subtitle: Text(role,
                      style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
    );
  }

  void _showInviteSheet(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final phoneCtrl = TextEditingController();
    String selectedRole = 'site_engineer';
    const roles = [
      'owner',
      'admin',
      'project_manager',
      'site_engineer',
      'viewer',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(l.inviteMemberTitle,
                              style:
                                  Theme.of(ctx).textTheme.titleMedium)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l.memberPhone,
                      hintText: '+251 9XX XXX XXX',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: l.memberRole,
                      border: const OutlineInputBorder(),
                    ),
                    items: roles
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedRole = v ?? selectedRole),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () async {
                        final phone = phoneCtrl.text.trim();
                        if (phone.isEmpty) return;
                        try {
                          final dio = ref.read(dioClientProvider);
                          // First look up the user by phone
                          final userResp = await dio.get(
                              ApiEndpoints.orgMembers,
                              params: {'phone': phone});
                          final users =
                              (userResp.data as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                                  [];
                          if (users.isEmpty) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text(l.memberAddFailed),
                                    backgroundColor: AppColors.error),
                              );
                            }
                            return;
                          }
                          await dio.post(
                            ApiEndpoints.projectTeam(projectId),
                            data: {
                              'user_id': users[0]['id'],
                              'role_on_project': selectedRole,
                            },
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(l.memberAdded),
                                  backgroundColor: AppColors.levelGreen),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(l.memberAddFailed),
                                  backgroundColor: AppColors.error),
                            );
                          }
                        }
                      },
                      child: Text(l.inviteMember,
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
      ),
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
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _ProjectAppBar(
          projectName: l.loadingEllipsis, projectId: projectId),
      body: Column(
        children: [
          // Hero skeleton — dark card
          Container(
            height: 160,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueprintInk.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          // Tab bar skeleton
          Container(
            height: 44,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 64,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.concrete.withValues(alpha: i == 0 ? 0.5 : 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          // Row skeletons
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, i) => Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1))
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.concrete.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 11,
                            width: 140,
                            decoration: BoxDecoration(
                              color: AppColors.concrete.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 8,
                            width: 90,
                            decoration: BoxDecoration(
                              color: AppColors.concrete.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60, height: 11,
                      decoration: BoxDecoration(
                        color: AppColors.concrete.withValues(alpha: 0.25),
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
