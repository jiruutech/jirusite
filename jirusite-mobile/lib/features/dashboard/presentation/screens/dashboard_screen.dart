import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/currency.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared_widgets/empty_state.dart';
import '../../../../shared_widgets/sync_status_badge.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _orgProjectsProvider =
    StreamProvider.autoDispose.family<List<LocalProject>, String>(
  (ref, orgId) => ref.read(appDatabaseProvider).watchProjects(orgId),
);

enum _ProjectFilter { all, active, needsAttention, completed }

final _filterProvider =
    StateProvider.autoDispose<_ProjectFilter>((_) => _ProjectFilter.all);

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final user = authState?.user;
    final orgId = user?.organizationId;
    final l = AppLocalizations.of(context);

    if (orgId == null) {
      return Scaffold(
        appBar: const _DashboardAppBar(orgName: 'JIRUSite'),
        body: EmptyState(
          icon: Icons.business_outlined,
          title: l.noOrganisation,
          subtitle: l.completeOrgSetup,
          actionLabel: l.setUp,
          onAction: () => context.go('/org-setup'),
        ),
      );
    }

    return _DashboardScaffold(
      orgId: orgId,
      userName: user?.fullName.split(' ').first ?? '',
    );
  }
}

// ── Main scaffold ─────────────────────────────────────────────────────────────

class _DashboardScaffold extends ConsumerWidget {
  const _DashboardScaffold({required this.orgId, required this.userName});
  final String orgId;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(_orgProjectsProvider(orgId));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _DashboardAppBar(orgName: userName),
      floatingActionButton: _QuickAddFab(orgId: orgId),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(syncEngineProvider).sync().ignore();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          slivers: [
            // ── Summary cards ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: projectsAsync.when(
                loading: () => const _SummarySkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (projects) => _SummarySection(projects: projects),
              ),
            ),

            // ── Budget vs Spent chart ──────────────────────────────────
            SliverToBoxAdapter(
              child: projectsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (projects) {
                  final active = projects
                      .where((p) =>
                          p.status == 'active' ||
                          p.status == 'planning' ||
                          p.status == 'in_progress')
                      .toList();
                  if (active.isEmpty) return const SizedBox.shrink();
                  return _BudgetChartCard(projects: active);
                },
              ),
            ),

            // ── Filter + project list ──────────────────────────────────
            const SliverToBoxAdapter(child: _FilterChipRow()),

            projectsAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: _ProjectListSkeleton()),
              error: (e, _) => SliverFillRemaining(
                child: ErrorState(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(_orgProjectsProvider(orgId)),
                ),
              ),
              data: (projects) =>
                  _ProjectListSliver(projects: projects),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const _DashboardAppBar({required this.orgName});
  final String orgName;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider);
    final hasUnread = pending > 0;
    final l = AppLocalizations.of(context);

    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.blueprintInk,
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Avatar / greeting
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.safetyOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_work_outlined,
                  color: AppColors.chalk, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName.isNotEmpty
                        ? '${l.dashboard} · $orgName'
                        : l.dashboard,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.chalk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SyncStatusBadge(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/notifications'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.chalk, size: 24),
                  if (hasUnread)
                    Positioned(
                      top: -1, right: -1,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.safetyOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary section ────────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.projects});
  final List<LocalProject> projects;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // Count projects by any non-completed status as "active"
    final active = projects
        .where((p) =>
            p.status != 'completed' &&
            p.status != 'cancelled' &&
            p.status != 'on_hold')
        .toList();
    final completed =
        projects.where((p) => p.status == 'completed').toList();

    final totalBudget =
        active.fold<double>(0, (s, p) => s + (p.totalBudget ?? 0));
    final totalSpent =
        active.fold<double>(0, (s, p) => s + (p.totalSpent ?? 0));
    final overBudget = active
        .where((p) =>
            (p.totalBudget ?? 0) > 0 &&
            (p.totalSpent ?? 0) > (p.totalBudget ?? 0))
        .length;

    final budgetRatio =
        totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final healthColor = budgetRatio < 0.75
        ? AppColors.levelGreen
        : budgetRatio < 0.9
            ? AppColors.ochreDust
            : AppColors.rebarRust;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Row 1 — 3 stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.construction_outlined,
                  iconColor: AppColors.safetyOrange,
                  label: l.activeProjects,
                  value: '${active.length}',
                  subtitle: projects.isNotEmpty
                      ? '${completed.length} ${l.completed.toLowerCase()}'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.blueprintInk,
                  label: l.totalBudget,
                  value: formatEtbCompact(totalBudget),
                  subtitle: totalBudget > 0 ? 'ETB' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  iconColor: overBudget > 0
                      ? AppColors.rebarRust
                      : AppColors.levelGreen,
                  label: l.totalSpent,
                  value: formatEtbCompact(totalSpent),
                  subtitle: totalBudget > 0
                      ? '${(budgetRatio * 100).toStringAsFixed(0)}%'
                      : null,
                  subtitleColor: healthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2 — Portfolio health progress bar
          if (totalBudget > 0)
            _PortfolioHealthCard(
              totalBudget: totalBudget,
              totalSpent: totalSpent,
              overBudgetCount: overBudget,
              healthColor: healthColor,
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.numeric.copyWith(
                fontSize: 20, color: AppColors.blueprintInk),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 10,
                    color: subtitleColor ?? AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _PortfolioHealthCard extends StatelessWidget {
  const _PortfolioHealthCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.overBudgetCount,
    required this.healthColor,
  });

  final double totalBudget;
  final double totalSpent;
  final int overBudgetCount;
  final Color healthColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ratio = (totalSpent / totalBudget).clamp(0.0, 1.0);
    final remaining = totalBudget - totalSpent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.portfolioHealth,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (overBudgetCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.rebarRust.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$overBudgetCount ${l.trendingOverBudget.toLowerCase()}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.rebarRust,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation(healthColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BudgetPill(
                  label: l.spent,
                  value: formatEtbCompact(totalSpent),
                  color: healthColor),
              _BudgetPill(
                  label: l.remaining,
                  value: formatEtbCompact(remaining.abs()),
                  color: remaining >= 0
                      ? AppColors.levelGreen
                      : AppColors.rebarRust),
              _BudgetPill(
                  label: l.budget,
                  value: formatEtbCompact(totalBudget),
                  color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetPill extends StatelessWidget {
  const _BudgetPill(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: AppTextStyles.numeric.copyWith(
                  fontSize: 13, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      );
}

// ── Budget vs Spent bar chart ──────────────────────────────────────────────────

class _BudgetChartCard extends StatelessWidget {
  const _BudgetChartCard({required this.projects});
  final List<LocalProject> projects;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Take top 5 projects by budget for the chart
    final top = [...projects]
      ..sort((a, b) =>
          (b.totalBudget ?? 0).compareTo(a.totalBudget ?? 0));
    final display = top.take(5).toList();

    final maxBudget = display.fold<double>(
        0, (m, p) => (p.totalBudget ?? 0) > m ? (p.totalBudget ?? 0) : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 18, color: AppColors.blueprintInk),
                const SizedBox(width: 6),
                Text(l.budgetByCostCode,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.sortedByVariance,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxBudget > 0 ? maxBudget * 1.1 : 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.blueprintInk.withValues(alpha: 0.9),
                      getTooltipItem: (group, _, rod, __) {
                        final p = display[group.x];
                        final isSpent = rod.color == AppColors.safetyOrange;
                        return BarTooltipItem(
                          '${p.name}\n${isSpent ? l.spent : l.budget}: ${formatEtbCompact(rod.toY)}',
                          const TextStyle(
                              color: AppColors.chalk, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx >= display.length) {
                            return const SizedBox.shrink();
                          }
                          final name = display[idx].name;
                          final short = name.length > 6
                              ? '${name.substring(0, 5)}…'
                              : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(short,
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary)),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFEEEEEE),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: display.asMap().entries.map((e) {
                    final p = e.value;
                    final budget = p.totalBudget ?? 0;
                    final spent = p.totalSpent ?? 0;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: budget,
                          color: AppColors.blueprintInk.withValues(alpha: 0.2),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: spent,
                          color: spent > budget
                              ? AppColors.rebarRust
                              : AppColors.safetyOrange,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                    color: AppColors.blueprintInk.withValues(alpha: 0.2),
                    label: l.budget),
                const SizedBox(width: 16),
                _LegendDot(
                    color: AppColors.safetyOrange, label: l.spent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

// ── Filter chip row ────────────────────────────────────────────────────────────

class _FilterChipRow extends ConsumerWidget {
  const _FilterChipRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_filterProvider);
    final l = AppLocalizations.of(context);

    final labels = {
      _ProjectFilter.all: l.all,
      _ProjectFilter.active: l.active,
      _ProjectFilter.needsAttention: l.needsAttention,
      _ProjectFilter.completed: l.completed,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.projects,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _ProjectFilter.values.map((filter) {
                final isActive = filter == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(_filterProvider.notifier).state = filter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.safetyOrange
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: AppColors.safetyOrange
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]
                            : const [
                                BoxShadow(
                                    color: Color(0x0D000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1))
                              ],
                      ),
                      child: Text(
                        labels[filter]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Project list sliver ────────────────────────────────────────────────────────

class _ProjectListSliver extends ConsumerWidget {
  const _ProjectListSliver({required this.projects});
  final List<LocalProject> projects;

  List<LocalProject> _applyFilter(
      List<LocalProject> all, _ProjectFilter filter) {
    return switch (filter) {
      _ProjectFilter.all => all,
      _ProjectFilter.active => all
          .where((p) =>
              p.status != 'completed' &&
              p.status != 'cancelled')
          .toList(),
      _ProjectFilter.needsAttention => all
          .where((p) =>
              (p.totalBudget ?? 0) > 0 &&
              (p.totalSpent ?? 0) > (p.totalBudget ?? 0) * 0.85)
          .toList(),
      _ProjectFilter.completed =>
        all.where((p) => p.status == 'completed').toList(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final filtered = _applyFilter(projects, filter);
    final l = AppLocalizations.of(context);

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.foundation,
          title: filter == _ProjectFilter.all
              ? l.noProjects
              : l.noProjectsInFilter,
          subtitle: filter == _ProjectFilter.all
              ? l.createFirstProject
              : null,
          actionLabel:
              filter == _ProjectFilter.all ? l.newProject : null,
          onAction: filter == _ProjectFilter.all
              ? () => context.push('/projects')
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ProjectCard(project: filtered[i]),
      ),
    );
  }
}

// ── Modern project card ────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final LocalProject project;

  @override
  Widget build(BuildContext context) {
    final budget = project.totalBudget ?? 0;
    final spent = project.totalSpent ?? 0;
    final ratio =
        budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final healthColor = ratio < 0.75
        ? AppColors.levelGreen
        : ratio < 0.9
            ? AppColors.ochreDust
            : AppColors.rebarRust;

    final isOverBudget = budget > 0 && spent > budget;

    return GestureDetector(
      onTap: () => context.push('/projects/${project.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stripe
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: healthColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blueprintInk,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(
                          status: project.status,
                          isOverBudget: isOverBudget),
                    ],
                  ),

                  if (project.locationText != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          project.locationText!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],

                  if (budget > 0) ...[
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor:
                            AlwaysStoppedAnimation(healthColor),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Budget stats row
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniStat(
                          label: 'Budget',
                          value: _compact(budget),
                          color: AppColors.textSecondary,
                        ),
                        _MiniStat(
                          label: 'Spent',
                          value: _compact(spent),
                          color: healthColor,
                        ),
                        _MiniStat(
                          label: isOverBudget ? 'Over' : 'Left',
                          value:
                              _compact((budget - spent).abs()),
                          color: isOverBudget
                              ? AppColors.rebarRust
                              : AppColors.levelGreen,
                        ),
                        _MiniStat(
                          label: 'Used',
                          value:
                              '${(ratio * 100).toStringAsFixed(0)}%',
                          color: healthColor,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: AppTextStyles.numeric
                  .copyWith(fontSize: 12, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary)),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.status, required this.isOverBudget});
  final String status;
  final bool isOverBudget;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (isOverBudget) {
      color = AppColors.rebarRust;
      label = '⚠ Over';
    } else if (status == 'completed') {
      color = AppColors.levelGreen;
      label = '✓ Done';
    } else if (status == 'on_hold') {
      color = AppColors.ochreDust;
      label = 'On Hold';
    } else {
      color = AppColors.levelGreen;
      label = 'Active';
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ── Skeleton loaders ──────────────────────────────────────────────────────────

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectListSkeleton extends StatelessWidget {
  const _ProjectListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Quick-add FAB ──────────────────────────────────────────────────────────────

class _QuickAddFab extends ConsumerWidget {
  const _QuickAddFab({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return FloatingActionButton(
      onPressed: () => _showQuickAddSheet(context, ref),
      backgroundColor: AppColors.safetyOrange,
      foregroundColor: AppColors.chalk,
      shape: const CircleBorder(),
      tooltip: l.quickAdd,
      child: const Icon(Icons.add, size: 28),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.chalk,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _QuickAddSheet(orgId: orgId),
    );
  }
}

class _QuickAddSheet extends ConsumerWidget {
  const _QuickAddSheet({required this.orgId});
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects =
        ref.watch(_orgProjectsProvider(orgId)).valueOrNull ?? [];
    final l = AppLocalizations.of(context);

    final recentProject = projects
        .where((p) => p.status != 'completed')
        .fold<LocalProject?>(
          null,
          (best, p) =>
              best == null || p.updatedAt.isAfter(best.updatedAt)
                  ? p
                  : best,
        );
    final projectId = recentProject?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.concrete,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(l.quickAdd,
                    style: Theme.of(context).textTheme.titleMedium),
                if (recentProject != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '· ${recentProject.name}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _QuickAddTile(
              icon: Icons.receipt_long_outlined,
              label: l.newExpenseShort,
              color: AppColors.blueprintInk,
              onTap: () {
                Navigator.pop(context);
                if (projectId != null) {
                  context.push('/projects/$projectId/expenses/new');
                } else {
                  context.push('/projects');
                }
              },
            ),
            _QuickAddTile(
              icon: Icons.people_outlined,
              label: l.laborEntryShort,
              color: AppColors.levelGreen,
              onTap: () {
                Navigator.pop(context);
                if (projectId != null) {
                  context.push('/projects/$projectId/labor/new');
                } else {
                  context.push('/projects');
                }
              },
            ),
            _QuickAddTile(
              icon: Icons.assignment_outlined,
              label: l.purchaseOrderShort,
              color: AppColors.safetyOrange,
              onTap: () {
                Navigator.pop(context);
                if (projectId != null) {
                  context
                      .push('/projects/$projectId/purchase-orders/new');
                } else {
                  context.push('/projects');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 20),
            ],
          ),
        ),
      );
}
