import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../../../shared_widgets/empty_state.dart';

final _materialsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, search) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.materials,
      params: search.isEmpty ? null : {'search': search});
  return (resp.data as List).cast<Map<String, dynamic>>();
});

final _priceHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, materialId) async {
  final dio = ref.read(dioClientProvider);
  final resp = await dio.get(ApiEndpoints.materialPriceHistory(materialId),
      params: {'region': 'Addis Ababa', 'days': '90'});
  return (resp.data as List).cast<Map<String, dynamic>>();
});

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  String _search = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final materialsAsync = ref.watch(_materialsProvider(_search));

    return Scaffold(
      appBar: AppBar(title: Text(l.materialsAndPrices)),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: l.searchMaterials,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),

          Expanded(
            child: materialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (materials) {
                if (materials.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: l.noMaterialsFound,
                  );
                }
                return ListView.builder(
                  itemCount: materials.length,
                  itemBuilder: (_, i) {
                    final m = materials[i];
                    final isSelected = _selectedId == m['id'];
                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 18),
                          ),
                          title: Text(m['name'] as String),
                          subtitle: Text('${m['category']} · ${m['standard_unit']}',
                              style: Theme.of(context).textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right),
                          selected: isSelected,
                          onTap: () => setState(() =>
                              _selectedId = isSelected ? null : m['id'] as String),
                        ),
                        if (isSelected) _PriceHistoryPanel(materialId: m['id'] as String),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReportPriceDialog(context),
        icon: const Icon(Icons.add_chart),
        label: Text(l.reportPrice),
      ),
    );
  }

  void _showReportPriceDialog(BuildContext context) {
    final l = AppLocalizations.of(context);
    // TODO: implement price reporting form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.priceReportingComingSoon)),
    );
  }
}

class _PriceHistoryPanel extends ConsumerWidget {
  const _PriceHistoryPanel({required this.materialId});
  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final historyAsync = ref.watch(_priceHistoryProvider(materialId));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: historyAsync.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('${l.failedToLoadPrices}: $e', style: const TextStyle(color: AppColors.error)),
        data: (prices) {
          if (prices.isEmpty) {
            return Text(l.noPriceHistory,
                style: const TextStyle(color: AppColors.textSecondary));
          }
          final latest = prices.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.currentPriceAddis,
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(formatEtb(parseDouble(latest['price'])),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              if (prices.length > 1) _PriceTrendChart(prices: prices),
            ],
          );
        },
      ),
    );
  }
}

class _PriceTrendChart extends StatelessWidget {
  const _PriceTrendChart({required this.prices});
  final List<Map<String, dynamic>> prices;

  @override
  Widget build(BuildContext context) {
    final reversed = prices.reversed.toList();
    final spots = reversed.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), parseDoubleOrZero(e.value['price']))).toList();

    return SizedBox(
      height: 100,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
