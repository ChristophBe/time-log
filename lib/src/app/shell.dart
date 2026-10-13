import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_providers.dart';
import '../features/shortcuts/shortcuts_sheet.dart';
import 'shortcuts.dart';
import 'design.dart';
import 'theme.dart';

/// The three places the app has, and how they are reached (SPEC §8).
///
/// A bottom bar on phones, a rail from the medium breakpoint, an extended rail
/// on a desktop-sized window. One widget rather than three, because the
/// destinations and the index are the same question however it is drawn.
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const double _railBreakpoint = 600;
  static const double _extendedBreakpoint = 1240;

  static const List<({IconData icon, IconData selected, String label})>
  _destinations = <({IconData icon, IconData selected, String label})>[
    (
      icon: Icons.schedule_outlined,
      selected: Icons.schedule_rounded,
      label: 'Today',
    ),
    (
      icon: Icons.history_outlined,
      selected: Icons.history_rounded,
      label: 'History',
    ),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  void _go(int index) => shell.goBranch(
    index,
    // Tapping the destination you are already on pops back to its root, which
    // is what every platform's tab bar does.
    initialLocation: index == shell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => CallbackShortcuts(
    // Global, because SPEC §10.5 lists these globally: whichever destination
    // you are on, `?` says what the keys do and Cmd/Ctrl+F starts a search.
    bindings: <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.question): () =>
          showShortcutsSheet(context),
      const SingleActivator(LogicalKeyboardKey.slash, shift: true): () =>
          showShortcutsSheet(context),
      commandActivator(LogicalKeyboardKey.keyF): () {
        _go(1);
        ref.read(historySearchRequestProvider.notifier).request();
      },
    },
    child: _scaffold(context),
  );

  /// Measured from the box the shell is given, not from the window.
  ///
  /// They are the same thing on a phone and different everywhere else — a
  /// window split in two, or anything that embeds the app — and it is the space
  /// actually available that decides whether a rail fits.
  Widget _scaffold(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _forWidth(context, constraints.maxWidth),
  );

  Widget _forWidth(BuildContext context, double width) {
    if (width < _railBreakpoint) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: <Widget>[
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selected),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: width >= _extendedBreakpoint,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            labelType: width >= _extendedBreakpoint
                ? null
                : NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selected),
                  label: Text(destination.label),
                ),
            ],
          ),
          Container(
            width: Strokes.hairline,
            color: AppColors.from(context).hairline,
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
