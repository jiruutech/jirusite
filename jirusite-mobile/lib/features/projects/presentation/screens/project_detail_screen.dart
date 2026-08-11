import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
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

// ── Screen ────────────────────────────────────────────────────────────────────

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_projectDashboardProvider(projectId));

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
        return _ProjectDetailLoaded(
          projectId: projectId,
          projectName: name,
          data: data,
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
        tooltip: 'Add expense',
        child: const Icon(Icons.add, size: 26),
      ),
      body: DefaultTabController(
        length: 6,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
              child: _ProjectHero(data: data),
            ),
            const SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(projectId: projectId, data: data),
              _PlaceholderTab(
                label: 'Expenses',
                onAction: () =>
                    context.push('/projects/$projectId/expenses'),
              ),
              _PlaceholderTab(
                label: 'Labour',
                onAction: () =>
                    context.push('/projects/$projectId/labor'),
              ),
              _PlaceholderTab(
                label: 'Materials',
                onAction: () =>
                    context.push('/projects/$projectId/expenses'),
              ),
              _PlaceholderTab(
                label: 'Schedule',
                onAction: () =>
                    context.push('/projects/$projectId/schedule'),
              ),
              _PlaceholderTab(
                label: 'Team',
                onAction: () => context.push('/projects/$projectId'),
              ),
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
              tooltip: 'Back',
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
        ? 'Trending over budget'
        : ratio > 0.85
            ? 'Approaching budget limit'
            : 'On track';

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
                  label: 'Budget',
                  value: formatEtb(totalBudget),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  width: 0.5,
                  height: 28,
                  color: AppColors.concrete,
                ),
                _HeroStat(
                  label: 'Spent',
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
                  label: 'Remaining',
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.chalk,
        border: Border(
          bottom: BorderSide(color: AppColors.concrete, width: 0.5),
        ),
      ),
      child: const TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.safetyOrange,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicatorColor: AppColors.safetyOrange,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Expenses'),
          Tab(text: 'Labour'),
          Tab(text: 'Materials'),
          Tab(text: 'Schedule'),
          Tab(text: 'Team'),
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
          const SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'Budget by Cost Code',
              trailing: 'Sorted by variance',
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
        const SliverToBoxAdapter(
          child: _SectionLabel(label: 'Recent Activity'),
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
                child: const Text(
                  'See all activity',
                  style: TextStyle(
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
    final relTime = createdAt != null ? _relativeTime(createdAt) : '';

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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(
        'No recent activity',
        style: TextStyle(
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
              label: 'Days left',
              value: '$daysRemaining',
            ),
          if (schedPct != null) ...[
            if (daysRemaining != null) const _FooterDivider(),
            _FooterStat(
              label: 'Schedule',
              value: '${schedPct!.toStringAsFixed(0)}%',
            ),
          ],
          if (pendingSync > 0) ...[
            if (daysRemaining != null || schedPct != null)
              const _FooterDivider(),
            _FooterStat(
              label: 'Pending sync',
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
  const _PlaceholderTab({required this.label, required this.onAction});
  final String label;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            child: Text('View $label'),
          ),
        ],
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
    return Scaffold(
      backgroundColor: AppColors.chalk,
      appBar: _ProjectAppBar(
          projectName: 'Loading…', projectId: projectId),
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
