// ignore_for_file: prefer_const_constructors
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportPriceSheet(
        materials: ref.read(_materialsProvider(_search)).valueOrNull ?? [],
      ),
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

// ── Report Price Bottom Sheet ──────────────────────────────────────────────

class _ReportPriceSheet extends ConsumerStatefulWidget {
  const _ReportPriceSheet({required this.materials});
  final List<Map<String, dynamic>> materials;

  @override
  ConsumerState<_ReportPriceSheet> createState() => _ReportPriceSheetState();
}

class _ReportPriceSheetState extends ConsumerState<_ReportPriceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _regionCtrl = TextEditingController(text: 'Addis Ababa');

  Map<String, dynamic>? _selectedMaterial;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null) {
      setState(() => _error = AppLocalizations.of(context).selectMaterialFirst);
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.materialPrices, data: {
        'material_id': _selectedMaterial!['id'],
        'price': double.parse(_priceCtrl.text),
        'region': _regionCtrl.text.trim(),
        'unit': _selectedMaterial!['standard_unit'],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).priceSubmitted),
            backgroundColor: AppColors.levelGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).priceSubmitFailed;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unit = _selectedMaterial?['standard_unit'] as String? ?? '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.concrete,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.reportPriceTitle,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(l.reportPriceSubtitle,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Material picker
                    Text(l.selectMaterial,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selectedMaterial,
                      hint: Text(l.selectMaterial),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: widget.materials.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${m['name']} (${m['standard_unit']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (v) => setState(() {
                        _selectedMaterial = v;
                        _error = null;
                      }),
                      validator: (v) => v == null ? l.selectMaterialFirst : null,
                    ),
                    const SizedBox(height: 16),

                    // Price input
                    Text(l.pricePer(unit),
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'ETB  ',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixText: _selectedMaterial != null ? '/ $unit' : null,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return (n == null || n <= 0) ? l.enterValidPrice : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Region input
                    Text(l.regionLabel,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _regionCtrl,
                      decoration: InputDecoration(
                        hintText: l.regionHint,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? l.required : null,
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(l.submit,
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
