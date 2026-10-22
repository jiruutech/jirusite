import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/empty_state.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _billingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.subscription);
  return resp.data as Map<String, dynamic>;
});

// ── Tier config ───────────────────────────────────────────────────────────────

const _tierFeatures = {
  'starter': [
    ('1 active project', Icons.folder_outlined),
    ('Up to 3 users', Icons.people_outlined),
    ('Expense & labor tracking', Icons.receipt_long_outlined),
  ],
  'growth': [
    ('5 active projects', Icons.folder_outlined),
    ('Up to 10 users', Icons.people_outlined),
    ('Materials pricing', Icons.inventory_2_outlined),
    ('Purchase order workflow', Icons.assignment_outlined),
  ],
  'professional': [
    ('20 active projects', Icons.folder_outlined),
    ('Up to 25 users', Icons.people_outlined),
    ('All features', Icons.star_outlined),
    ('SMS notifications', Icons.sms_outlined),
    ('Priority support', Icons.support_agent_outlined),
  ],
  'enterprise': [
    ('Unlimited projects', Icons.all_inclusive_outlined),
    ('Unlimited users', Icons.people_outlined),
    ('All features + API access', Icons.code_outlined),
    ('Dedicated support', Icons.support_agent_outlined),
    ('Custom integrations', Icons.integration_instructions_outlined),
  ],
};

const _tierPrices = {
  'starter': 0,
  'growth': 1200,
  'professional': 3500,
  'enterprise': 8000,
};

const _tierColors = {
  'starter': AppColors.textSecondary,
  'growth': AppColors.levelGreen,
  'professional': AppColors.safetyOrange,
  'enterprise': Color(0xFF9C27B0),
};

// ── Screen ────────────────────────────────────────────────────────────────────

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final billingAsync = ref.watch(_billingProvider);
    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(title: Text(l.billingAndSubscription)),
      body: billingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(_billingProvider)),
        data: (data) {
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final payments =
              (data['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final currentTier =
              sub['subscription_tier'] as String? ?? 'starter';
          final status =
              sub['subscription_status'] as String? ?? 'trial';
          final trialEndsAt = sub['trial_ends_at'] as String?;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_billingProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // ── Current plan hero card ──────────────────────────────
                _CurrentPlanCard(
                  tier: currentTier,
                  status: status,
                  trialEndsAt: trialEndsAt,
                ),
                const SizedBox(height: 24),

                // ── Upgrade plans ───────────────────────────────────────
                if (user?.canApprove ?? false) ...[
                  Text(l.upgradePlan,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueprintInk)),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the plan that fits your project scale',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ..._buildTierCards(context, ref, currentTier, user),
                  const SizedBox(height: 24),
                ],

                // ── Payment history ─────────────────────────────────────
                if (payments.isNotEmpty) ...[
                  const Text('Payment History',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blueprintInk)),
                  const SizedBox(height: 12),
                  ...payments.map((p) => _PaymentCard(payment: p)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTierCards(BuildContext context, WidgetRef ref,
      String currentTier, user) {
    const tiers = ['starter', 'growth', 'professional', 'enterprise'];
    return tiers.map((tier) {
      final isCurrent = tier == currentTier;
      return _TierPlanCard(
        tier: tier,
        isCurrent: isCurrent,
        onUpgrade: (user?.canApprove ?? false) && !isCurrent
            ? () => _showUpgradeSheet(context, ref, tier)
            : null,
      );
    }).toList();
  }

  void _showUpgradeSheet(
      BuildContext context, WidgetRef ref, String tier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(
        tier: tier,
        onSuccess: () => ref.invalidate(_billingProvider),
      ),
    );
  }
}

// ── Current plan card ─────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.tier,
    required this.status,
    this.trialEndsAt,
  });
  final String tier;
  final String status;
  final String? trialEndsAt;

  @override
  Widget build(BuildContext context) {
    final price = _tierPrices[tier] ?? 0;
    final color = _tierColors[tier] ?? AppColors.blueprintInk;
    final features = _tierFeatures[tier] ?? [];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.blueprintInk, color.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.blueprintInk.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tier[0].toUpperCase()}${tier.substring(1)} Plan',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                          price > 0
                              ? 'ETB ${_compact(price.toDouble())}'
                              : 'Free',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                        if (price > 0)
                          const Text('/month',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            if (trialEndsAt != null && status == 'trial') ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: Colors.white60),
                const SizedBox(width: 5),
                Text(
                  'Trial ends ${trialEndsAt!.substring(0, 10)}',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => _FeatureChip(f.$1)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.levelGreen,
      'trial' => AppColors.ochreDust,
      'expired' => AppColors.rebarRust,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      );
}

// ── Tier plan card ────────────────────────────────────────────────────────────

class _TierPlanCard extends StatelessWidget {
  const _TierPlanCard({
    required this.tier,
    required this.isCurrent,
    this.onUpgrade,
  });
  final String tier;
  final bool isCurrent;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final price = _tierPrices[tier] ?? 0;
    final color = _tierColors[tier] ?? AppColors.blueprintInk;
    final features = _tierFeatures[tier] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tier == 'starter'
                        ? Icons.rocket_launch_outlined
                        : tier == 'growth'
                            ? Icons.trending_up
                            : tier == 'professional'
                                ? Icons.workspace_premium_outlined
                                : Icons.diamond_outlined,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                            '${tier[0].toUpperCase()}${tier.substring(1)}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: color)),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Current',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: color,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      Text(
                        price > 0
                            ? 'ETB ${price.toString()}/month'
                            : 'Free forever',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Features
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(f.$2, size: 14, color: color),
                const SizedBox(width: 8),
                Text(f.$1,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
              ]),
            )),
            if (onUpgrade != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    price > 0 ? '${l.upgrade} — ETB $price/mo' : l.upgrade,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Upgrade flow — bottom sheet → Chapa WebView ───────────────────────────────

class _UpgradeSheet extends ConsumerStatefulWidget {
  const _UpgradeSheet({required this.tier, required this.onSuccess});
  final String tier;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _startPayment() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(authStateProvider).valueOrNull?.user;
      final dio = ref.read(dioClientProvider);
      final resp = await dio.post(ApiEndpoints.chapaInitiate, data: {
        'tier': widget.tier,
        if (user?.phoneNumber != null)
          'phone_number': user!.phoneNumber.replaceAll('+', '').replaceAll(' ', ''),
        'first_name': user?.fullName.split(' ').first ?? 'User',
        'last_name': user?.fullName.split(' ').skip(1).join(' ').isNotEmpty == true
            ? user!.fullName.split(' ').skip(1).join(' ')
            : 'JIRUSite',
      });

      final checkoutUrl = resp.data['checkout_url'] as String?;
      final txRef = resp.data['tx_ref'] as String?;

      if (checkoutUrl == null) {
        setState(() { _error = 'Could not get checkout URL'; _loading = false; });
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);

      // Open Chapa checkout in WebView
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _ChapaWebViewScreen(
            checkoutUrl: checkoutUrl,
            txRef: txRef,
          ),
        ),
      );

      if (result == true) {
        widget.onSuccess();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Subscription activated! Thank you.'),
              backgroundColor: AppColors.levelGreen,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _tierPrices[widget.tier] ?? 0;
    final color = _tierColors[widget.tier] ?? AppColors.blueprintInk;
    final tierName =
        '${widget.tier[0].toUpperCase()}${widget.tier.substring(1)}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.concrete,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              // Plan summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.workspace_premium_outlined,
                          color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upgrade to $tierName',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          Text('ETB $price per month',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Payment method info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.levelGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Secure payment via Chapa. Supports Telebirr, CBE Birr, M-Pesa, and bank cards.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Pay ETB $price with Chapa',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chapa WebView screen ──────────────────────────────────────────────────────

class _ChapaWebViewScreen extends StatefulWidget {
  const _ChapaWebViewScreen({
    required this.checkoutUrl,
    this.txRef,
  });
  final String checkoutUrl;
  final String? txRef;

  @override
  State<_ChapaWebViewScreen> createState() => _ChapaWebViewScreenState();
}

class _ChapaWebViewScreenState extends State<_ChapaWebViewScreen> {
  InAppWebViewController? _webCtrl;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chapa Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.checkoutUrl),
        ),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          javaScriptEnabled: true,
          userAgent: 'JIRUSite/1.0 Flutter',
        ),
        onWebViewCreated: (ctrl) {
          _webCtrl = ctrl;
          // Register handler for payment completion signal from the return page
          ctrl.addJavaScriptHandler(
            handlerName: 'paymentComplete',
            callback: (_) {
              Navigator.pop(context, true);
            },
          );
        },
        onLoadStop: (ctrl, url) {
          setState(() => _loading = false);
          final urlStr = url?.toString() ?? '';
          // Detect return URL pattern — payment complete
          if (urlStr.contains('/billing/chapa/return')) {
            Navigator.pop(context, true);
          }
        },
        onLoadStart: (_, __) => setState(() => _loading = true),
        shouldOverrideUrlLoading: (ctrl, action) async {
          final url = action.request.url?.toString() ?? '';
          // If Chapa redirects to our return URL, close WebView as success
          if (url.contains('/billing/chapa/return')) {
            Navigator.pop(context, true);
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onReceivedError: (_, __, err) {
          setState(() => _loading = false);
        },
      ),
    );
  }
}

// ── Payment history card ──────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final status = payment['status'] as String? ?? 'pending';
    final color = switch (status) {
      'success' => AppColors.levelGreen,
      'failed' => AppColors.rebarRust,
      _ => AppColors.ochreDust,
    };
    final icon = switch (status) {
      'success' => Icons.check_circle_outline,
      'failed' => Icons.cancel_outlined,
      _ => Icons.schedule_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          formatEtb(parseDouble(payment['amount'])),
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          payment['billing_period_start'] as String? ?? '',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
      ),
    );
  }
}
