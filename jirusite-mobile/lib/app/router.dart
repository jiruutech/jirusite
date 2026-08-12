import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/generated/app_localizations.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/org_setup_screen.dart';
import '../features/auth/presentation/screens/language_select_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/projects/presentation/screens/project_list_screen.dart';
import '../features/projects/presentation/screens/project_detail_screen.dart';
import '../features/expenses/presentation/screens/expense_list_screen.dart';
import '../features/expenses/presentation/screens/expense_entry_screen.dart';
import '../features/labor/presentation/screens/labor_list_screen.dart';
import '../features/labor/presentation/screens/labor_entry_screen.dart';
import '../features/materials_pricing/presentation/screens/materials_screen.dart';
import '../features/suppliers/presentation/screens/supplier_list_screen.dart';
import '../features/purchase_orders/presentation/screens/purchase_order_list_screen.dart';
import '../features/purchase_orders/presentation/screens/purchase_order_create_screen.dart';
import '../features/schedule/presentation/screens/schedule_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Listen to auth state so router rebuilds on login/logout
  final authNotifier = ValueNotifier<bool>(false);
  ref.listen(authStateProvider, (_, next) {
    authNotifier.value = next.valueOrNull?.isAuthenticated ?? false;
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authVal = ref.read(authStateProvider).valueOrNull;
      final isAuthenticated = authVal?.isAuthenticated ?? false;
      final hasOrg = authVal?.user?.hasOrganization ?? false;
      final loc = state.matchedLocation;

      // Pure auth screens — never require login
      final isLoginFlow = loc == '/login' ||
          loc == '/register' ||
          loc.startsWith('/otp');

      // Post-auth onboarding screens — require login but not org
      final isOnboarding = loc == '/org-setup' || loc == '/language';

      // 1. Not logged in → send to login (except login-flow screens)
      if (!isAuthenticated && !isLoginFlow && !isOnboarding) return '/login';

      // 2. Logged in but no org → must finish org setup
      //    (allow /language only after org is set up)
      if (isAuthenticated && !hasOrg && loc != '/org-setup') return '/org-setup';

      // 3. Fully authenticated with org → redirect away from login/register
      if (isAuthenticated && hasOrg && isLoginFlow) return '/dashboard';

      // All other cases (dashboard, projects/:id, expenses, language, etc.) — allow
      return null;
    },
    routes: [
      // ── Auth routes ────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpScreen(phoneNumber: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/org-setup', builder: (_, __) => const OrgSetupScreen()),
      GoRoute(path: '/language', builder: (_, __) => const LanguageSelectScreen()),

      // ── Main shell with bottom nav ─────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/projects',
            builder: (_, __) => const ProjectListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    ProjectDetailScreen(projectId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'expenses',
                    builder: (_, s) =>
                        ExpenseListScreen(projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'expenses/new',
                    builder: (_, s) =>
                        ExpenseEntryScreen(projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'labor',
                    builder: (_, s) =>
                        LaborListScreen(projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'labor/new',
                    builder: (_, s) =>
                        LaborEntryScreen(projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'purchase-orders',
                    builder: (_, s) => PurchaseOrderListScreen(
                        projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'purchase-orders/new',
                    builder: (_, s) => PurchaseOrderCreateScreen(
                        projectId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'schedule',
                    builder: (_, s) =>
                        ScheduleScreen(projectId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/materials',
            builder: (_, __) => const MaterialsScreen(),
          ),
          GoRoute(
            path: '/suppliers',
            builder: (_, __) => const SupplierListScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/billing',
            builder: (_, __) => const BillingScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bottom navigation shell — wraps all main screens.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static int _indexFromPath(String path) {
    if (path.startsWith('/projects')) return 1;
    if (path.startsWith('/materials') || path.startsWith('/suppliers')) return 2;
    if (path.startsWith('/notifications')) return 3;
    if (path.startsWith('/settings') || path.startsWith('/billing')) return 4;
    return 0; // /dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFromPath(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/dashboard');
            case 1:
              context.go('/projects');
            case 2:
              context.go('/materials');
            case 3:
              context.go('/notifications');
            case 4:
              context.go('/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_work_outlined),
            selectedIcon: const Icon(Icons.home_work),
            label: AppLocalizations.of(context).dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.foundation),
            selectedIcon: const Icon(Icons.foundation),
            label: AppLocalizations.of(context).projects,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: AppLocalizations.of(context).materials,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: AppLocalizations.of(context).notifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context).settings,
          ),
        ],
      ),
    );
  }
}
