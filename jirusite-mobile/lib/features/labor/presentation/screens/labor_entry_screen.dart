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

const _uuidL = Uuid();

class LaborEntryScreen extends ConsumerStatefulWidget {
  const LaborEntryScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<LaborEntryScreen> createState() => _LaborEntryScreenState();
}

class _LaborEntryScreenState extends ConsumerState<LaborEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _workersCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _workersCtrl.dispose();
    _rateCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    final workers = int.tryParse(_workersCtrl.text) ?? 1;
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    if (rate > 0) setState(() => _totalCtrl.text = (workers * rate).toStringAsFixed(2));
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final user = ref.read(authStateProvider).valueOrNull?.user;
    if (user == null) { setState(() => _saving = false); return; }

    final clientId = _uuidL.v4();

    try {
      final db = ref.read(appDatabaseProvider);

      await db.insertLabor(LocalLaborEntry(
        id: clientId,
        projectId: widget.projectId,
        enteredBy: user.id,
        workerOrCrewName: _nameCtrl.text.trim(),
        totalAmount: double.parse(_totalCtrl.text),
        workDate: _dateStr,
        createdAt: DateTime.now(),
        workDescription: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        numberOfWorkers: int.tryParse(_workersCtrl.text) ?? 1,
        dailyRate: double.tryParse(_rateCtrl.text),
        syncStatus: 'pending',
      ));

      final isOnline = ref.read(isOnlineProvider);
      if (isOnline) ref.read(syncEngineProvider).sync().ignore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline
                ? 'Labor entry saved & syncing'
                : 'Labor entry saved — will sync when online'),
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
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Labor Entry')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppTextField(
                label: 'Worker / Crew Name *',
                controller: _nameCtrl,
                hint: 'Rebar Crew (Gebru & team)',
                prefixIcon: const Icon(Icons.people_outlined),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Work Description',
                controller: _descCtrl,
                hint: 'Foundation rebar installation, ground floor',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: AppTextField(
                    label: 'Workers',
                    controller: _workersCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _recalcTotal(),
                    validator: (v) =>
                        (int.tryParse(v ?? '') == null) ? 'Invalid' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Daily Rate (ETB)',
                    controller: _rateCtrl,
                    hint: '450',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _recalcTotal(),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Total Amount (ETB) *',
                controller: _totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n <= 0) ? 'Enter total amount' : null;
                },
              ),
              const SizedBox(height: 16),

              // Date
              Text('Work Date *', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(_dateStr, style: Theme.of(context).textTheme.bodyLarge),
                  ]),
                ),
              ),

              if (!isOnline) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.syncPending.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.wifi_off, size: 16, color: AppColors.syncPending),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're offline — will sync when connected.",
                        style: TextStyle(fontSize: 12, color: AppColors.syncPending),
                      ),
                    ),
                  ]),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],

              const SizedBox(height: 28),
              AppButton(
                label: 'Save Labor Entry',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                icon: Icons.save_outlined,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
