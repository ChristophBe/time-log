import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/models/app_settings.dart';
import '../features/today/day_rollover.dart';
import 'router.dart';
import 'theme.dart';

class TimeLogApp extends ConsumerStatefulWidget {
  const TimeLogApp({super.key});

  @override
  ConsumerState<TimeLogApp> createState() => _TimeLogAppState();
}

class _TimeLogAppState extends ConsumerState<TimeLogApp> {
  final _router = buildRouter();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The app's only lifecycle hook, and SPEC §9.3's resume work: a midnight
    // that passed while the app was away has to be cut once it is back, since
    // §4.5 forbids writing the cut before it happened.
    _lifecycle = AppLifecycleListener(onResume: _rollOver);
    _rollOver();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _rollOver() => unawaited(ref.read(dayRolloverProvider.notifier).check());

  @override
  Widget build(BuildContext context) {
    // The 30-second tick the rest of the app already runs on, rather than a
    // timer set for the next midnight: the instants §6.11 writes are the
    // midnights themselves, so noticing late costs nothing but the lag on the
    // header date.
    ref.listen<AsyncValue<DateTime>>(
      coarseTickerProvider,
      (_, _) => _rollOver(),
    );

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
