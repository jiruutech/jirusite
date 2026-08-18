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

final _poListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.projectPurchaseOrders(projectId));
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class PurchaseOrderListScreen extends ConsumerWidget {
  const PurchaseOrderListScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final posAsync = ref.watch(_poListProvider(projectId));
    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return Scaffold(
      appBar: AppBar(title: Text(l.purchaseOrders)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/$projectId/purchase-orders/new'),
        icon: const Icon(Icons.add),
        label: Text(l.newPO),
      ),
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.refresh(_poListProvider(projectId))),
        data: (pos) {
          if (pos.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: l.noPurchaseOrders,
              actionLabel: l.createPO,
              onAction: () => context.push('/projects/$projectId/purchase-orders/new'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pos.length,
            itemBuilder: (_, i) => _PoCard(
              po: pos[i],
              canApprove: user?.canApprove ?? false,
              onRefresh: () => ref.refresh(_poListProvider(projectId)),
            ),
          );
        },
      ),
    );
  }
}

class _PoCard extends ConsumerWidget {
  const _PoCard({required this.po, required this.canApprove, required this.onRefresh});
  final Map<String, dynamic> po;
  final bool canApprove;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = po['status'] as String? ?? 'pending';
    final color = switch (status) {
      'approved'  => AppColors.success,
      'pending'   => AppColors.warning,
      'cancelled' => AppColors.error,
      'delivered' => AppColors.primary,
      _           => AppColors.textSecondary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PO #${(po['id'] as String).substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium),
                _StatusBadge(status: status, color: color),
              ],
            ),
            if (po['supplier_name'] != null) ...[
              const SizedBox(height: 4),
              Text('${l.supplier}: ${po['supplier_name']}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(formatEtb(parseDouble(po['total_amount'])),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.primary)),
            if (status == 'pending' && canApprove) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(l.approve),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success),
                      onPressed: () => _approve(context, ref, 'approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(l.reject),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error),
                      onPressed: () => _approve(context, ref, 'reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String action) async {
    final l = AppLocalizations.of(context);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.patch(ApiEndpoints.approvePO(po['id'] as String), data: {'action': action});
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.failed}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}
