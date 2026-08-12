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
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final l = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.newProject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l.projectName)),
            const SizedBox(height: 12),
            TextField(controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.totalBudgetEtb)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () async {
              final dio = ref.read(dioClientProvider);
              await dio.post(ApiEndpoints.projects, data: {
                'name': nameCtrl.text.trim(),
                if (budgetCtrl.text.isNotEmpty) 'total_budget': double.tryParse(budgetCtrl.text),
                'currency': 'ETB',
              });
              ref.invalidate(projectListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.create),
          ),
        ],
      ),
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({required this.project});
  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
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
                    Text('${formatEtb(spent)} spent', style: Theme.of(context).textTheme.bodySmall),
                    Text('of ${formatEtb(budget)}', style: Theme.of(context).textTheme.bodySmall),
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
