import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/app/app_navigator.dart';
import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';
import 'package:lecture_viewer_v3/features/home/presentation/home_screen.dart';
import 'package:lecture_viewer_v3/features/settings/presentation/settings_screen.dart';

class LectureViewerApp extends ConsumerWidget {
  const LectureViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Lecture Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/settings') {
          return MaterialPageRoute<void>(
            builder: (_) => const SettingsScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
