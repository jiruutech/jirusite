import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/app_text_field.dart';

class PurchaseOrderCreateScreen extends ConsumerStatefulWidget {
  const PurchaseOrderCreateScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<PurchaseOrderCreateScreen> createState() =>
      _PurchaseOrderCreateScreenState();
}

class _PurchaseOrderCreateScreenState
    extends ConsumerState<PurchaseOrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final List<_LineItem> _items = [_LineItem()];
  bool _saving = false;
  String? _error;

  double get _total => _items.fold(0, (sum, i) => sum + i.lineTotal);

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final l = AppLocalizations.of(context);
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.projectPurchaseOrders(widget.projectId), data: {
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'items': _items.map((i) => {
          'quantity': i.quantity,
          'unit_price': i.unitPrice,
          'line_total': i.lineTotal,
        }).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.poSubmitted),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.newPurchaseOrder)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.lineItems, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._items.asMap().entries.map((e) => _LineItemWidget(
                  item: e.value,
                  index: e.key,
                  onRemove: _items.length > 1
                      ? () => setState(() => _items.removeAt(e.key))
                      : null,
                  onChanged: () => setState(() {}),
                )),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_LineItem())),
                  icon: const Icon(Icons.add),
                  label: Text(l.addLineItem),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.notes,
                  controller: _notesCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.total, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(formatEtb(_total),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: l.submitForApproval,
                  onPressed: _saving ? null : _submit,
                  isLoading: _saving,
                  icon: Icons.send_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineItem {
  double quantity = 1;
  double unitPrice = 0;
  double get lineTotal => quantity * unitPrice;
}

class _LineItemWidget extends StatelessWidget {
  const _LineItemWidget(
      {required this.item, required this.index, this.onRemove, required this.onChanged});
  final _LineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(l.itemNumber(index + 1),
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemove),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.qty),
                    onChanged: (v) {
                      item.quantity = double.tryParse(v) ?? 1;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.unitPriceEtb),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? l.invalidNumber : null,
                    onChanged: (v) {
                      item.unitPrice = double.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(l.lineTotal(formatEtb(item.lineTotal)),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
