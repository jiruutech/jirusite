import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/empty_state.dart';

final _billingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.subscription);
  return resp.data as Map<String, dynamic>;
});

const _tierFeatures = {
  'starter': ['1 project', '3 users', 'Basic tracking'],
  'growth': ['5 projects', '10 users', 'Materials pricing', 'PO workflow'],
  'professional': ['20 projects', '25 users', 'All features', 'SMS alerts'],
  'enterprise': ['Unlimited projects', 'Unlimited users', 'Priority support', 'API access'],
};

const _tierPrices = {
  'starter': 0,
  'growth': 1200,
  'professional': 3500,
  'enterprise': 8000,
};

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final billingAsync = ref.watch(_billingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.billingAndSubscription)),
      body: billingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(_billingProvider)),
        data: (data) {
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final payments = (data['payments'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final currentTier = sub['subscription_tier'] as String? ?? 'starter';
          final status = sub['subscription_status'] as String? ?? 'trial';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current plan card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentTier[0].toUpperCase() + currentTier.substring(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatEtb(_tierPrices[currentTier]?.toDouble()),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text('/month', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Upgrade options
              Text(l.upgradePlan, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...['growth', 'professional', 'enterprise']
                  .where((t) => t != currentTier)
                  .map((tier) => _TierCard(tier: tier, current: currentTier,
                        onUpgrade: () => _initiatePay(context, ref, tier))),

              const SizedBox(height: 24),

              // Payment history
              if (payments.isNotEmpty) ...[
                Text(l.paymentHistory, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...payments.map((p) => _PaymentTile(payment: p)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _initiatePay(BuildContext context, WidgetRef ref, String tier) async {
    final l = AppLocalizations.of(context);
    final tierName = tier[0].toUpperCase() + tier.substring(1);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.upgradeTo(tierName)),
        content: Text(l.upgradeMessage(formatEtb(_tierPrices[tier]?.toDouble()))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final dio = ref.read(dioClientProvider);
                await dio.post(ApiEndpoints.telebirrInitiate, data: {'tier': tier});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.telebirrInitiated),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l.failed}: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(l.payWithTelebirr),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.current, required this.onUpgrade});
  final String tier;
  final String current;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final features = _tierFeatures[tier] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tier[0].toUpperCase() + tier.substring(1),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${formatEtb(_tierPrices[tier]?.toDouble())}${l.month}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.check, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(f, style: Theme.of(context).textTheme.bodySmall),
              ]),
            )),
            const SizedBox(height: 12),
            AppButton(
              label: l.upgrade,
              onPressed: onUpgrade,
              minimumSize: const Size(double.infinity, 42),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final status = payment['status'] as String? ?? 'pending';
    final color = status == 'success' ? AppColors.success
        : status == 'failed' ? AppColors.error : AppColors.warning;
    return ListTile(
      leading: Icon(
        status == 'success' ? Icons.check_circle : Icons.schedule,
        color: color,
      ),
      title: Text(formatEtb(parseDouble(payment['amount']))),
      subtitle: Text(payment['billing_period_start'] as String? ?? ''),
      trailing: Text(status.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
