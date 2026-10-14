import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared_widgets/empty_state.dart';

final projectListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.projects);
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(l.projects),
        actions: [
          if ((user?.canApprove ?? false) || (user?.canCreateExpense ?? false))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add, color: AppColors.chalk, size: 18),
                label: Text(l.newProject,
                    style: const TextStyle(color: AppColors.chalk)),
              ),
            ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(projectListProvider)),
        data: (projects) {
          if (projects.isEmpty) {
            return EmptyState(
              icon: Icons.construction_outlined,
              title: l.noProjects,
              subtitle: l.createFirstProject,
              actionLabel: l.newProject,
              onAction: () => _showCreateDialog(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(projectListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: projects.length,
              itemBuilder: (_, i) =>
                  _ProjectCard(project: projects[i]),
            ),
          );
        },
      ),
      floatingActionButton: (user?.canApprove ?? false) ||
              (user?.canCreateExpense ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.newProject),
            )
          : null,
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProjectSheet(
          onCreated: () => ref.invalidate(projectListProvider)),
    );
  }
}

// ── Modern project card ────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = parseDouble(project['total_budget']) ?? 0.0;
    final spent = parseDoubleOrZero(project['total_spent']);
    final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final healthColor = ratio < 0.75
        ? AppColors.levelGreen
        : ratio < 0.9
            ? AppColors.ochreDust
            : AppColors.rebarRust;
    final isOverBudget = budget > 0 && spent > budget;
    final status = project['status'] as String? ?? 'active';

    return GestureDetector(
      onTap: () => context.push('/projects/${project['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Top accent bar
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: healthColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blueprintInk,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                          status: status, isOverBudget: isOverBudget),
                    ],
                  ),
                  if (project['location_text'] != null) ...[
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          project['location_text'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],

                  if (budget > 0) ...[
                    const SizedBox(height: 14),

                    // Mini bar chart — 4 weeks of expenses if available,
                    // else just the progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: AlwaysStoppedAnimation(healthColor),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatPill(
                            label: l.budget,
                            value: _compact(budget),
                            color: AppColors.textSecondary),
                        _StatPill(
                            label: l.spent,
                            value: _compact(spent),
                            color: healthColor),
                        _StatPill(
                            label: isOverBudget ? 'Over' : l.remaining,
                            value: _compact((budget - spent).abs()),
                            color: isOverBudget
                                ? AppColors.rebarRust
                                : AppColors.levelGreen),
                        _StatPill(
                            label: 'Used',
                            value:
                                '${(ratio * 100).toStringAsFixed(0)}%',
                            color: healthColor),
                      ],
                    ),
                  ],

                  // Date range if available
                  if (project['start_date'] != null ||
                      project['target_end_date'] != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.date_range_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _dateRange(project),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ]),
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

  String _dateRange(Map<String, dynamic> p) {
    final start = p['start_date'] as String?;
    final end = p['target_end_date'] as String?;
    if (start != null && end != null) return '$start → $end';
    if (start != null) return 'Started $start';
    if (end != null) return 'Due $end';
    return '';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isOverBudget});
  final String status;
  final bool isOverBudget;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (isOverBudget) {
      color = AppColors.rebarRust;
      label = '⚠ Over Budget';
    } else if (status == 'completed') {
      color = AppColors.levelGreen;
      label = '✓ Completed';
    } else if (status == 'on_hold') {
      color = AppColors.ochreDust;
      label = 'On Hold';
    } else if (status == 'planning') {
      color = AppColors.blueprintInk;
      label = 'Planning';
    } else {
      color = AppColors.levelGreen;
      label = 'Active';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
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
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary)),
        ],
      );
}

// ── Create Project Sheet ───────────────────────────────────────────────────────

class _CreateProjectSheet extends ConsumerStatefulWidget {
  const _CreateProjectSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState
    extends ConsumerState<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.projects, data: {
        'name': _nameCtrl.text.trim(),
        if (_budgetCtrl.text.isNotEmpty)
          'total_budget': double.tryParse(_budgetCtrl.text),
        'currency': 'ETB',
        if (_locationCtrl.text.trim().isNotEmpty)
          'location_text': _locationCtrl.text.trim(),
        if (_startDate != null) 'start_date': _fmt(_startDate!),
        if (_endDate != null) 'target_end_date': _fmt(_endDate!),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.concrete,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.safetyOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.construction_outlined,
                        color: AppColors.safetyOrange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(l.newProject,
                          style:
                              Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l.projectName,
                        prefixIcon: const Icon(Icons.badge_outlined,
                            size: 18),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? l.required : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l.totalBudgetEtb,
                        prefixText: 'ETB  ',
                        prefixIcon:
                            const Icon(Icons.account_balance_wallet_outlined,
                                size: 18),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(
                        labelText: l.locationLabel,
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            size: 18),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _DatePickerTile(
                          label: l.startDateLabel,
                          value: _startDate,
                          onPicked: (d) =>
                              setState(() => _startDate = d),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DatePickerTile(
                          label: l.endDateLabel,
                          value: _endDate,
                          firstDate: _startDate,
                          onPicked: (d) =>
                              setState(() => _endDate = d),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.safetyOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text(l.create,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onPicked,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (d != null) onPicked(d);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.concrete),
          borderRadius: BorderRadius.circular(8),
          color: value != null
              ? AppColors.blueprintInk.withValues(alpha: 0.03)
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14,
                color: value != null
                    ? AppColors.safetyOrange
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null
                    ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(
                  fontSize: 12,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
