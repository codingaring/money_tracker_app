// Reference UI redesign: 4 branches (홈/내역/분석/계좌) + center docked FAB
// for /input + /settings pushed from Home AppBar. /accounts/card/:id stays
// nested under /accounts so back gesture pops to AccountsScreen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/ui/accounts_screen.dart';
import '../features/accounts/ui/card_detail_screen.dart';
import '../features/analytics/ui/analytics_screen.dart';
import '../features/categories/ui/categories_screen.dart';
import '../features/dashboard/ui/home_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/templates/ui/templates_screen.dart';
import '../features/transactions/ui/input_screen.dart';
import '../features/transactions/ui/list_screen.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/list',
              builder: (_, _) => const TransactionListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/analytics',
              builder: (_, _) => const AnalyticsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/accounts',
              builder: (_, _) => const AccountsScreen(),
              routes: [
                GoRoute(
                  path: 'card/:id',
                  builder: (_, state) => CardDetailScreen(
                    accountId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Top-level push routes — replace the shell so they cover the FAB+bar.
      GoRoute(
        path: '/input',
        builder: (_, _) => const InputScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'templates',
            builder: (_, _) => const TemplatesScreen(),
          ),
          GoRoute(
            path: 'categories',
            builder: (_, _) => const CategoriesScreen(),
          ),
        ],
      ),
    ],
  );
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        heroTag: 'shell-input-fab',
        onPressed: () => context.push('/input'),
        elevation: 6,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(navigationShell: navigationShell),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = <_NavItemSpec>[
    _NavItemSpec(label: '홈', icon: Icons.home_outlined, selectedIcon: Icons.home, index: 0),
    _NavItemSpec(label: '내역', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, index: 1),
    _NavItemSpec(label: '분석', icon: Icons.donut_large_outlined, selectedIcon: Icons.donut_large, index: 2),
    _NavItemSpec(label: '계좌', icon: Icons.account_balance_outlined, selectedIcon: Icons.account_balance, index: 3),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomAppBar(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in _items.take(2))
              _NavItem(
                spec: item,
                selected: navigationShell.currentIndex == item.index,
                onTap: () => _goBranch(item.index),
              ),
            const SizedBox(width: 56), // gap reserved for the docked FAB
            for (final item in _items.skip(2))
              _NavItem(
                spec: item,
                selected: navigationShell.currentIndex == item.index,
                onTap: () => _goBranch(item.index),
              ),
          ],
        ),
      ),
    );
  }

  void _goBranch(int i) {
    navigationShell.goBranch(
      i,
      initialLocation: i == navigationShell.currentIndex,
    );
  }
}

class _NavItemSpec {
  const _NavItemSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.index,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _NavItemSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? spec.selectedIcon : spec.icon,
                size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              spec.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
