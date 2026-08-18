import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared_widgets/app_button.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});
  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrlList =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusList = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrlList) { c.dispose(); }
    for (final f in _focusList) { f.dispose(); }
    super.dispose();
  }

  String get _code => _ctrlList.map((c) => c.text).join();

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    if (_code.length < 6) {
      setState(() => _error = l.enterAllDigits);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.otpVerify, data: {
        'phone_number': widget.phoneNumber,
        'code': _code,
      });
      // OTP verified — navigate based on whether user is already authenticated
      if (mounted) {
        final user = ref.read(authStateProvider).valueOrNull?.user;
        if (user != null && user.hasOrganization) {
          context.go('/dashboard');
        } else if (user != null) {
          context.go('/org-setup');
        } else {
          context.go('/login');
        }
      }
    } on DioException catch (e) {
      setState(() {
        _error = _parseOtpError(e, AppLocalizations.of(context));
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = AppLocalizations.of(context).errorOccurred;
        _loading = false;
      });
    }
  }

  String _parseOtpError(DioException e, AppLocalizations l) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = (data['error'] ?? data['message'] ?? '').toString().toLowerCase();
      if (msg.contains('invalid') || msg.contains('expired') || msg.contains('incorrect')) {
        return 'Invalid or expired code. Please request a new one.';
      }
    }
    return l.errorOccurred;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.otpTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(l.otpSubtitle(widget.phoneNumber),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _buildDigitBox(i)),
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
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            AppButton(label: l.verify, onPressed: _verify, isLoading: _loading),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(authStateProvider.notifier)
                  .requestOtp(widget.phoneNumber),
              child: Text(l.resendCode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 48, height: 60,
      child: TextFormField(
        controller: _ctrlList[index],
        focusNode: _focusList[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _focusList[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _focusList[index - 1].requestFocus();
        },
      ),
    );
  }
}
