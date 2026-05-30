import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/workout_plan.dart';
import 'active/active_workout_screen.dart';
import 'activity/activity_calendar_screen.dart';
import 'builder/plan_builder_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'home/home_screen.dart';
import 'plans/plan_list_screen.dart';
import 'scan/scan_screen.dart';
import 'settings/reminders_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const home = '/home';
  static const plans = '/plans';
  static const activity = '/activity';
  static const scan = '/scan';
  static const control = '/control';
  static const planBuilder = '/plans/edit';
  static const activeWorkout = '/active';
  static const reminders = '/reminders';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.plans,
              builder: (context, state) => const PlanListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.activity,
              builder: (context, state) => const ActivityCalendarScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.scan,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: AppRoutes.control,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.planBuilder,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          PlanBuilderScreen(existing: state.extra as WorkoutPlan?),
    ),
    GoRoute(
      path: AppRoutes.activeWorkout,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ActiveWorkoutScreen(plan: state.extra as WorkoutPlan),
    ),
    GoRoute(
      path: AppRoutes.reminders,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RemindersScreen(),
    ),
  ],
);

/// Hosts the persistent bottom [NavigationBar] for the tabbed branches.
class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Plans',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Activity',
          ),
        ],
      ),
    );
  }
}
