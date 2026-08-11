import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          const _SectionHeader(title: 'Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(user?.fullName ?? 'Unknown'),
            subtitle: Text(user?.phoneNumber ?? ''),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user?.role ?? 'viewer',
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ),
          ),

          // Language
          const _SectionHeader(title: 'Language'),
          ...kLocaleNames.entries.map((e) {
            final isSelected = locale.languageCode == e.key;
            return InkWell(
              onTap: () =>
                  ref.read(localeProvider.notifier).setLocale(Locale(e.key)),
              child: ListTile(
                title: Text(e.value),
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            );
          }),

          // Organization
          const _SectionHeader(title: 'Organization'),
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text('Team Members'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Billing & Subscription'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/billing'),
          ),

          // About
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('JIRUSite'),
            subtitle: Text('Version 1.0.0'),
          ),

          // Logout
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Log Out', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                ref.read(authStateProvider.notifier).logout();
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      );
}
