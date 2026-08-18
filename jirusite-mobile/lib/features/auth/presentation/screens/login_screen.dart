import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../shared_widgets/app_button.dart';
import '../../../../shared_widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).login(
          _phoneCtrl.text.trim(),
          _passCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authAsync = ref.watch(authStateProvider);
    final isLoading = authAsync.isLoading;
    final error = authAsync.valueOrNull?.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.construction, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appName,
                            style: Theme.of(context).textTheme.headlineMedium),
                        Text(l.constructionCostTracking,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text(l.welcomeBack,
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(l.signInWithPhone,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        )),
                const SizedBox(height: 32),

                AppTextField(
                  label: l.phoneNumber,
                  controller: _phoneCtrl,
                  hint: '+251 9XX XXX XXX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l.fieldRequired(l.phoneNumber);
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: l.password,
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.fieldRequired(l.password);
                    return null;
                  },
                ),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error,
                            style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                AppButton(
                  label: l.loginButton,
                  onPressed: isLoading ? null : _login,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: Text('${l.dontHaveAccount} ${l.register}'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/otp', extra: _phoneCtrl.text.trim()),
                    child: Text(l.forgotPassword),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
