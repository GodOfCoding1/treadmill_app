import 'package:go_router/go_router.dart';

import '../domain/workout_plan.dart';
import 'active/active_workout_screen.dart';
import 'activity/activity_calendar_screen.dart';
import 'builder/plan_builder_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'plans/plan_list_screen.dart';
import 'scan/scan_screen.dart';
import 'settings/reminders_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const scan = '/';
  static const dashboard = '/dashboard';
  static const plans = '/plans';
  static const planBuilder = '/plans/edit';
  static const activeWorkout = '/active';
  static const activity = '/activity';
  static const reminders = '/reminders';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.scan,
  routes: [
    GoRoute(
      path: AppRoutes.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.plans,
      builder: (context, state) => const PlanListScreen(),
    ),
    GoRoute(
      path: AppRoutes.planBuilder,
      builder: (context, state) =>
          PlanBuilderScreen(existing: state.extra as WorkoutPlan?),
    ),
    GoRoute(
      path: AppRoutes.activeWorkout,
      builder: (context, state) =>
          ActiveWorkoutScreen(plan: state.extra as WorkoutPlan),
    ),
    GoRoute(
      path: AppRoutes.activity,
      builder: (context, state) => const ActivityCalendarScreen(),
    ),
    GoRoute(
      path: AppRoutes.reminders,
      builder: (context, state) => const RemindersScreen(),
    ),
  ],
);
