import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'notifications/notification_service.dart';
import 'ui/router.dart';
import 'workout/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  WorkoutForegroundService.init();
  // Notification setup is best-effort: a failure here (e.g. a missing icon
  // resource) must never block the app from launching.
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('Notification init failed: $e\n$st');
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: TreadmillApp()));
}

class TreadmillApp extends StatelessWidget {
  const TreadmillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Treadmill',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
