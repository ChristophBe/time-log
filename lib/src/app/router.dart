import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Deep-linkable routes (SPEC §8).
///
/// A stateful shell, so each of the three destinations keeps its own navigation
/// stack and its own scroll position: switching to History and back should land
/// you on the day you were reading, not reset it.
GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (_, _) => const TodayScreen(),
              routes: <RouteBase>[
                // `/day/:isoDate` is what makes a particular day shareable and
                // restores it on reload.
                GoRoute(
                  path: 'day/:isoDate',
                  builder: (_, state) =>
                      TodayScreen(isoDate: state.pathParameters['isoDate']),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
