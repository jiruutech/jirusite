import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared_widgets/empty_state.dart';

final projectListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
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
      appBar: AppBar(title: Text(l.projects)),
      floatingActionButton: (user?.canApprove ?? false) || (user?.canCreateExpense ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.newProject),
            )
          : null,
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(projectListProvider)),
        data: (projects) {
          if (projects.isEmpty) {
            return EmptyState(
              icon: Icons.construction_outlined,
              title: l.noProjects,
              actionLabel: l.newProject,
              onAction: () => _showCreateDialog(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(projectListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (_, i) => _ProjectListTile(project: projects[i]),
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProjectSheet(onCreated: () => ref.invalidate(projectListProvider)),
    );
  }

}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final budget = parseDouble(project['total_budget']);
    final spent = parseDoubleOrZero(project['total_spent']);
    final health = budgetHealthPercent(budget, spent);
    final healthColor = health < 0.7 ? AppColors.budgetGood
        : health < 0.9 ? AppColors.budgetWarning : AppColors.budgetDanger;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/projects/${project['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(project['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium)),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: healthColor, shape: BoxShape.circle),
                  ),
                ],
              ),
              if (project['location_text'] != null) ...[
                const SizedBox(height: 4),
                Text(project['location_text'] as String,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (budget != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.spentAmount(formatEtb(spent)), style: Theme.of(context).textTheme.bodySmall),
                    Text(l.ofAmount(formatEtb(budget)), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: health.clamp(0.0, 1.0),
                  color: healthColor,
                  backgroundColor: AppColors.divider,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create Project Sheet ───────────────────────────────────────────────────

class _CreateProjectSheet extends ConsumerStatefulWidget {
  const _CreateProjectSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateProjectSheet> createState() =>
      _CreateProjectSheetState();
}

class _CreateProjectSheetState extends ConsumerState<_CreateProjectSheet> {
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

  String _formatDate(DateTime d) =>
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
        if (_startDate != null) 'start_date': _formatDate(_startDate!),
        if (_endDate != null) 'target_end_date': _formatDate(_endDate!),
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
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.concrete,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(l.newProject,
                      style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Name — required
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: l.projectName,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? l.required : null,
                    ),
                    const SizedBox(height: 14),

                    // Budget
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l.totalBudgetEtb,
                        prefixText: 'ETB  ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(
                        labelText: l.locationLabel,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Start date
                    _DatePickerTile(
                      label: l.startDateLabel,
                      value: _startDate,
                      onPicked: (d) => setState(() => _startDate = d),
                    ),
                    const SizedBox(height: 10),

                    // End date
                    _DatePickerTile(
                      label: l.endDateLabel,
                      value: _endDate,
                      firstDate: _startDate,
                      onPicked: (d) => setState(() => _endDate = d),
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(l.create,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 20),
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.concrete),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null
                    ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPicked(DateTime.now()),
                child: const Icon(Icons.clear,
                    size: 16, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
