import 'package:aptechka/features/home/presentation/home_screen.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_screen.dart';
import 'package:aptechka/features/inventory/presentation/inventory_screen.dart';
import 'package:aptechka/features/inventory/presentation/medicine_detail_screen.dart';
import 'package:aptechka/features/reminders/presentation/reminders_screen.dart';
import 'package:aptechka/features/scanner/presentation/barcode_scanner_screen.dart';
import 'package:aptechka/features/settings/presentation/settings_screen.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reminders',
              builder: (context, state) => const RemindersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medicine/new',
      builder: (context, state) => const AddMedicineScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medicine/:id',
      builder: (context, state) =>
          MedicineDetailScreen(medicineId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/scanner',
      builder: (context, state) => const BarcodeScannerScreen(),
    ),
  ],
);
