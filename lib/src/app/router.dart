import 'package:go_router/go_router.dart';

import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';

/// Deep-linkable routes (SPEC §8). `/day/:isoDate` is what makes a particular
/// day shareable and restores scroll position on reload.
GoRouter buildRouter() => GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => const TodayScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'day/:isoDate',
          builder: (_, state) =>
              TodayScreen(isoDate: state.pathParameters['isoDate']),
        ),
        GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
  ],
);
