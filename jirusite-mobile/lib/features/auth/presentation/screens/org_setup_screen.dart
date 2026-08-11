import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class OrgSetupScreen extends ConsumerStatefulWidget {
  const OrgSetupScreen({super.key});

  @override
  ConsumerState<OrgSetupScreen> createState() => _OrgSetupScreenState();
}

class _OrgSetupScreenState extends ConsumerState<OrgSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _tinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _tinCtrl.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authStateProvider.notifier).setupOrganization(
        _nameCtrl.text.trim(),
        _tinCtrl.text.trim().isEmpty ? null : _tinCtrl.text.trim(),
      );
      if (mounted) context.go('/language');
    } on Exception catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not create organisation. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Set Up Your Organization',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('This info helps us tailor the app for your business.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Company Name',
                  controller: _nameCtrl,
                  hint: 'Zemen Construction PLC',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'TIN Number (Optional)',
                  controller: _tinCtrl,
                  hint: '0001234567',
                  keyboardType: TextInputType.number,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                AppButton(label: 'Continue', onPressed: _setup, isLoading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
