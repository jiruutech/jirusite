import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared_widgets/empty_state.dart';

final _suppliersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, String>>((ref, filters) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.suppliers, params: filters.isEmpty ? null : filters);
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  String _category = '';
  bool _verifiedOnly = false;
  String _search = '';

  Map<String, String> get _filters => {
    if (_category.isNotEmpty) 'category': _category,
    if (_verifiedOnly) 'verified': 'true',
    if (_search.isNotEmpty) 'search': _search,
  };

  static const _categories = ['', 'cement', 'rebar', 'aggregate', 'electrical', 'plumbing', 'finishing'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final suppliersAsync = ref.watch(_suppliersProvider(_filters));

    return Scaffold(
      appBar: AppBar(title: Text(l.supplierDirectory)),
      body: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                FilterChip(
                  label: Text(l.verified),
                  selected: _verifiedOnly,
                  onSelected: (v) => setState(() => _verifiedOnly = v),
                ),
                const SizedBox(width: 8),
                ..._categories.skip(1).map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = _category == c ? '' : c),
                  ),
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: l.searchSuppliers,
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (suppliers) {
                if (suppliers.isEmpty) {
                  return EmptyState(
                    icon: Icons.storefront_outlined,
                    title: l.noSuppliersFound,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: suppliers.length,
                  itemBuilder: (_, i) => _SupplierCard(supplier: suppliers[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier});
  final Map<String, dynamic> supplier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isVerified = supplier['is_verified'] as bool? ?? false;
    final phone = supplier['phone_number'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(supplier['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(l.verified, style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            if (supplier['location_text'] != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(supplier['location_text'] as String,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
            if (supplier['category'] != null) ...[
              const SizedBox(height: 4),
              Text(supplier['category'] as String,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.primary)),
            ],
            if (phone != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _ContactButton(
                    icon: Icons.call_outlined,
                    label: l.call,
                    onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  ),
                  const SizedBox(width: 8),
                  _ContactButton(
                    icon: Icons.sms_outlined,
                    label: l.sms,
                    onTap: () => launchUrl(Uri.parse('sms:$phone')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}
