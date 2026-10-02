import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import '../domain/models/app_settings.dart';
import 'router.dart';
import 'theme.dart';

class TimeLogApp extends ConsumerStatefulWidget {
  const TimeLogApp({super.key});

  @override
  ConsumerState<TimeLogApp> createState() => _TimeLogAppState();
}

class _TimeLogAppState extends ConsumerState<TimeLogApp> {
  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    return MaterialApp.router(
      title: 'time-log',
      routerConfig: _router,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
