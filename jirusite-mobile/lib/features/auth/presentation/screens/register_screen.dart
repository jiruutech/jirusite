import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/app_text_field.dart';
import '../../../../app/theme.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).register(
      _nameCtrl.text.trim(), _phoneCtrl.text.trim(), _passCtrl.text, 'owner',
    );
    if (mounted) {
      final user = ref.read(authStateProvider).valueOrNull?.user;
      if (user != null && !user.hasOrganization) {
        context.push('/org-setup');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final error = ref.watch(authStateProvider).valueOrNull?.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  hint: 'Abebe Girma',
                  prefixIcon: const Icon(Icons.person_outlined),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Full name is required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Phone Number',
                  controller: _phoneCtrl,
                  hint: '+251911000001',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Phone number is required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                ),
                if (error != null) ...[
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
                            error,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                AppButton(label: 'Create Account', onPressed: _register, isLoading: isLoading),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
