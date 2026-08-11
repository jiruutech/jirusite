import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/app_text_field.dart';
import '../../../../shared_widgets/receipt_photo_capture.dart';

const _uuid = Uuid();

class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ExpenseEntryScreen> createState() =>
      _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();

  String _expenseType = 'material';
  String? _selectedUnit;
  String? _receiptLocalPath;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  static const _expenseTypes = ['material', 'labor', 'equipment', 'other'];
  static const _units = [
    'kg',
    'quintal',
    'm3',
    'piece',
    'sheet',
    'm2',
    'liter',
    'bag',
    'ton'
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final user = ref.read(authStateProvider).valueOrNull?.user;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final clientId = _uuid.v4();
    final now = DateTime.now();

    try {
      final db = ref.read(appDatabaseProvider);

      // ── Step 1: Write to local DB immediately (offline-first) ─────
      await db.insertExpense(LocalExpense(
        id: clientId,
        projectId: widget.projectId,
        enteredBy: user.id,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        expenseType: _expenseType,
        transactionDate: _dateStr,
        createdAt: now,
        updatedAt: now,
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        quantity: double.tryParse(_quantityCtrl.text),
        unit: _selectedUnit,
        receiptPhotoLocalPath: _receiptLocalPath,
        syncStatus: 'pending',
      ));

      // ── Step 2: Queue photo upload if provided ────────────────────
      if (_receiptLocalPath != null && _receiptLocalPath!.isNotEmpty) {
        await db.queuePhoto(clientId, _receiptLocalPath!);
      }

      // ── Step 3: Trigger sync immediately if online ────────────────
      final isOnline = ref.read(isOnlineProvider);
      if (isOnline) ref.read(syncEngineProvider).sync().ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.chalk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isOnline
                    ? 'Expense saved & syncing'
                    : 'Expense saved — will sync when online'),
              ),
            ]),
            backgroundColor: AppColors.levelGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Expense')),

      // ── Sticky Save button at bottom ─────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            label: 'Save Expense',
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            icon: Icons.save_outlined,
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            children: [
              // ── Expense type chips ─────────────────────────────────
              Text('Expense Type',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _expenseTypes
                    .map((t) => ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: _expenseType == t,
                          onSelected: (_) =>
                              setState(() => _expenseType = t),
                          selectedColor:
                              AppColors.blueprintInk.withValues(alpha: 0.12),
                          checkmarkColor: AppColors.blueprintInk,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // ── Amount with ETB prefix ─────────────────────────────
              Text('Amount *',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "ETB" fixed prefix — not inside the input
                  Container(
                    height: 50,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.concrete.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(color: AppColors.concrete),
                    ),
                    child: const Text(
                      'ETB',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  // Amount input
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      // Explicitly request numeric keyboard
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d,.]')),
                      ],
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.numeric.copyWith(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: AppColors.concrete),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: AppColors.concrete),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.blueprintInk, width: 1.5),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      validator: (v) {
                        final n = double.tryParse(
                            v?.replaceAll(',', '') ?? '');
                        return (n == null || n <= 0)
                            ? 'Enter a valid amount'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────────────
              AppTextField(
                label: 'Description',
                controller: _descCtrl,
                hint: 'e.g. Cement purchase — 50 quintals',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ── Quantity + Unit row ────────────────────────────────
              Row(children: [
                Expanded(
                  child: AppTextField(
                    label: 'Quantity',
                    controller: _quantityCtrl,
                    hint: '0.0',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unit',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      DropdownMenu<String>(
                        initialSelection: _selectedUnit,
                        hintText: 'Select',
                        width: double.infinity,
                        inputDecorationTheme: const InputDecorationTheme(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: _units
                            .map((u) => DropdownMenuEntry<String>(
                                  value: u,
                                  label: u,
                                ))
                            .toList(),
                        onSelected: (v) =>
                            setState(() => _selectedUnit = v),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Date picker ────────────────────────────────────────
              Text('Transaction Date *',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.concrete),
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.surface,
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 17, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(_dateStr,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Receipt photo — ALWAYS visible ─────────────────────
              ReceiptPhotoCapture(
                onPhotoSelected: (path) =>
                    setState(() =>
                        _receiptLocalPath = path.isNotEmpty ? path : null),
              ),
              const SizedBox(height: 20),

              // ── Offline banner ─────────────────────────────────────
              if (!isOnline)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.ochreDust.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.ochreDust.withValues(alpha: 0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.wifi_off,
                        size: 16, color: AppColors.ochreDust),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're offline — expense will sync automatically when connected.",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.ochreDust),
                      ),
                    ),
                  ]),
                ),

              // ── Error banner ───────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.rebarRust.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.rebarRust.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.rebarRust, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
