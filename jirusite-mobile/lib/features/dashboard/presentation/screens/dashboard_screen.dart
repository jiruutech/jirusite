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
import '../../../../shared_widgets/level_widget.dart';
import '../../../../shared_widgets/sync_status_badge.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Streams projects for the authenticated org from the local DB.
final _orgProjectsProvider =
    StreamProvider.autoDispose.family<List<LocalProject>, String>(
  (ref, orgId) => ref.read(appDatabaseProvider).watchProjects(orgId),
);

// ── Filter enum ───────────────────────────────────────────────────────────────

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
      orgName: user?.fullName ?? 'Organisation',
    );
  }
}

// ── Main scaffold ─────────────────────────────────────────────────────────────

class _DashboardScaffold extends ConsumerWidget {
  const _DashboardScaffold({required this.orgId, required this.orgName});
  final String orgId;
  final String orgName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(_orgProjectsProvider(orgId));

    return Scaffold(
      backgroundColor: AppColors.chalk,
      // Fixed 56px header per spec — no elevation, hairline bottom border only.
      appBar: _DashboardAppBar(orgName: orgName),
      floatingActionButton: _QuickAddFab(orgId: orgId),
      body: CustomScrollView(
        // CustomScrollView so the header can collapse in a future iteration
        // without a full rebuild — per the deliverable spec.
        slivers: [
          // ── Portfolio summary strip ───────────────────────────────────
          SliverToBoxAdapter(
            child: projectsAsync.when(
              loading: () => const _PortfolioStripSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
              data: (projects) => _PortfolioStrip(projects: projects),
            ),
          ),

          // ── Filter chip row ────────────────────────────────────────────
          const SliverToBoxAdapter(child: _FilterChipRow()),

          // ── Project list ───────────────────────────────────────────────
          projectsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: _ProjectListSkeleton(),
            ),
            error: (e, _) => SliverFillRemaining(
              child: ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(_orgProjectsProvider(orgId)),
              ),
            ),
            data: (projects) => _ProjectListSliver(projects: projects),
          ),

          // Bottom padding so FAB doesn't overlap last card
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DashboardAppBar({required this.orgName});
  final String orgName;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider);
    final hasUnread = pending > 0; // reuse pending count as unread signal

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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Hamburger
            const Icon(Icons.menu, color: AppColors.blueprintInk, size: 22),
            const SizedBox(width: 12),

            // Org name — center-left, truncates
            Expanded(
              child: Text(
                orgName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.blueprintInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Sync badge
            const SyncStatusBadge(),
            const SizedBox(width: 8),

            // Notification bell with unread dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none,
                    color: AppColors.blueprintInk, size: 22),
                if (hasUnread)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.safetyOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Portfolio summary strip ────────────────────────────────────────────────────

class _PortfolioStrip extends StatelessWidget {
  const _PortfolioStrip({required this.projects});
  final List<LocalProject> projects;

  @override
  Widget build(BuildContext context) {
    final active =
        projects.where((p) => p.status == 'active').toList();
    final l = AppLocalizations.of(context);

    // Portfolio-level aggregates
    final totalBudget = active.fold<double>(
        0, (sum, p) => sum + (p.totalBudget ?? 0));
    const double totalSpent = 0.0; // local DB doesn't store spent; Level Widget
    // will show indeterminate unless the pull enriches LocalProject.

    // This-month spend: not in local model yet; shown as placeholder
    const double? thisMonthSpend = null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MetricCard(
              label: l.activeProjects,
              child: Text(
                '${active.length}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blueprintInk,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: l.portfolioHealth,
              child: totalBudget > 0
                  ? LevelWidget(
                      budget: totalBudget,
                      spent: totalSpent,
                      showLabel: false,
                      height: 36,
                    )
                  : const _NoDataLine(),
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: l.thisMonth,
              child: thisMonthSpend != null
                  ? _MonthSpend(amount: thisMonthSpend)
                  : const _NoDataLine(),
            ),
            const SizedBox(width: 16), // trailing padding inside scroll
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        // Concrete-tinted background — sits in the page, doesn't float.
        color: AppColors.concrete.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSpend extends StatelessWidget {
  const _MonthSpend({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            formatEtbCompact(amount),
            style: AppTextStyles.numeric.copyWith(fontSize: 13),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _NoDataLine extends StatelessWidget {
  const _NoDataLine();

  @override
  Widget build(BuildContext context) => Container(
        height: 4,
        width: 48,
        decoration: BoxDecoration(
          color: AppColors.concrete.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _PortfolioStripSkeleton extends StatelessWidget {
  const _PortfolioStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 148,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.concrete.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ProjectFilter.values.map((filter) {
            final isActive = filter == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () =>
                    ref.read(_filterProvider.notifier).state = filter,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.safetyOrange.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive
                          ? AppColors.safetyOrange
                          : AppColors.concrete,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    labels[filter]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppColors.safetyOrange
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
      _ProjectFilter.active =>
        all.where((p) => p.status == 'active').toList(),
      _ProjectFilter.needsAttention => all
          .where((p) => p.status == 'active' && p.totalBudget != null)
          .toList(), // real variance filtering requires spent data
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
              : 'No projects in this filter',
          subtitle: filter == _ProjectFilter.all
              ? 'Create your first project to start tracking costs.'
              : null,
          actionLabel:
              filter == _ProjectFilter.all ? l.projects : null,
          onAction: filter == _ProjectFilter.all
              ? () => context.push('/projects')
              : null,
        ),
      );
    }

    return SliverList.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, i) => _ProjectRow(project: filtered[i]),
    );
  }
}

// ── Project row card ───────────────────────────────────────────────────────────

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});
  final LocalProject project;

  @override
  Widget build(BuildContext context) {
    final budget = project.totalBudget;
    // spent is not stored in LocalProject — show level widget in
    // indeterminate (no-budget) mode until sync enriches the model.
    const double spent = 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/projects/${project.id}'),
      child: Container(
        // Flat ledger-row treatment — chalk bg, concrete hairline border only.
        height: 96,
        decoration: const BoxDecoration(
          color: AppColors.chalk,
          border: Border(
            bottom: BorderSide(color: AppColors.concrete, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: name + location ───────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (project.locationText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      project.locationText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Budget figures — right-aligned monospace pair
                  if (budget != null && budget > 0)
                    Row(
                      children: [
                        Text(
                          'Budget ${_compactEtb(budget)}',
                          style: AppTextStyles.numeric.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 0.5,
                          height: 10,
                          color: AppColors.concrete,
                        ),
                        Text(
                          'Spent —',
                          style: AppTextStyles.numeric.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Right: compact Level Widget ─────────────────────────────
            SizedBox(
              width: 48,
              child: LevelWidget(
                budget: budget,
                spent: spent,
                showLabel: false,
                height: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactEtb(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Project list loading skeleton ──────────────────────────────────────────────

class _ProjectListSkeleton extends StatelessWidget {
  const _ProjectListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.chalk,
            border: Border(
              bottom: BorderSide(color: AppColors.concrete, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: 160,
                      decoration: BoxDecoration(
                        color: AppColors.concrete.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.concrete.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.concrete.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
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
    return FloatingActionButton(
      onPressed: () => _showQuickAddSheet(context, ref),
      backgroundColor: AppColors.safetyOrange,
      foregroundColor: AppColors.chalk,
      shape: const CircleBorder(),
      tooltip: 'Quick add expense, labour or PO',
      child: const Icon(Icons.add, size: 28),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    // Resolve the most-recently-viewed project from the project stream.
    // Falls back to /projects if none available.
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.chalk,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
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
    
    // Use most-recently-updated active project
    final recentProject = projects
        .where((p) => p.status == 'active')
        .fold<LocalProject?>(
          null,
          (best, p) =>
              best == null || p.updatedAt.isAfter(best.updatedAt) ? p : best,
        );
    final projectId = recentProject?.id;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.concrete,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(l.quickAdd,
                    style: Theme.of(context).textTheme.titleMedium),
                if (recentProject != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '· ${recentProject.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          _QuickAddTile(
            icon: Icons.receipt_long_outlined,
            label: l.newExpenseShort,
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
            onTap: () {
              Navigator.pop(context);
              if (projectId != null) {
                context.push('/projects/$projectId/purchase-orders/new');
              } else {
                context.push('/projects');
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blueprintInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, color: AppColors.blueprintInk, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      );
}
