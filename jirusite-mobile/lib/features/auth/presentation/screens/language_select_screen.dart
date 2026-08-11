import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../shared_widgets/app_button.dart';

class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  ConsumerState<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  String _selected = 'am';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Choose Your Language',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('You can change this later in Settings.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              ...kLocaleNames.entries.map((e) => _buildTile(e.key, e.value)),
              const Spacer(),
              AppButton(
                label: 'Continue',
                onPressed: () {
                  final router = GoRouter.of(context);
                  ref
                      .read(localeProvider.notifier)
                      .setLocale(Locale(_selected))
                      .then((_) {
                    if (mounted) router.go('/dashboard');
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(String code, String name) {
    final isSelected = _selected == code;
    return GestureDetector(
      onTap: () => setState(() => _selected = code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
