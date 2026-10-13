import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../domain/models/time_entry.dart';
import '../../domain/timeline_writer.dart';
import '../../app/design.dart';
import '../../app/platform_style.dart';
import '../../app/shortcuts.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/day_calendar.dart';
import '../calendar/zoom_control.dart';
import '../entry/entry_sheet.dart';
import 'day_header.dart';
import 'resume_action.dart';
import 'action_feedback.dart';
import 'start_action.dart';
import 'start_composer.dart';
import 'today_providers.dart';

/// The home screen (SPEC §8.1): what is running, the day, and the start
/// composer pinned to the bottom edge.
///
/// Stateful only to own the composer's [FocusNode], which `Cmd/Ctrl+N` needs a
/// handle on (SPEC §10.5).
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.isoDate});

  final String? isoDate;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _composer = StartComposerState();

  /// The screen's own focus, so the day-view shortcuts have somewhere to live
  /// once the composer gives focus up.
  final _screenFocus = FocusNode(debugLabel: 'today screen');

  /// How much room the floating header takes. Measured rather than assumed: it
  /// grows with the text scale, with the running activity's name, and with the
  /// device's safe area.
  double _headerHeight = 0;

  @override
  void dispose() {
    _composer.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(dayEntriesProvider);

    return CallbackShortcuts(
      // SPEC §10.5. The block-focused shortcuts live on the blocks themselves.
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            ref.read(selectedDayProvider.notifier).previousDay(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            ref.read(selectedDayProvider.notifier).nextDay(),
        const SingleActivator(LogicalKeyboardKey.keyT): () =>
            ref.read(selectedDayProvider.notifier).today(),
        // Focuses the field rather than opening anything: the control it would
        // have opened is already on screen (SPEC §10.5). Cmd on Apple, Ctrl
        // elsewhere -- not both, because Ctrl+N means something else on a Mac.
        commandActivator(LogicalKeyboardKey.keyN): _composer.focus.requestFocus,
        commandActivator(LogicalKeyboardKey.period): _stop,
        commandActivator(LogicalKeyboardKey.keyR): _resumeLast,
      },
      child: Focus(
        focusNode: _screenFocus,
        autofocus: true,
        child: _MenuBar(
          onStartSomething: _composer.focus.requestFocus,
          onStop: _stop,
          onResumeLast: _resumeLast,
          onSettings: () => context.go('/settings'),
          child: Scaffold(
            // The composer lives in this slot rather than as the last child of
            // the body for one reason: Scaffold keeps a floating SnackBar clear
            // of bottomNavigationBar, and the theme's SnackBars float. In the
            // body it would be covered by its own "Started X" undo for 8 seconds
            // -- exactly when the next start might be wanted.
            bottomNavigationBar: StartComposerBar(
              state: _composer,
              onRelease: _screenFocus.requestFocus,
            ),
            body: entriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) => _DatabaseError(error: error),
              data: (_) => _body(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Glass chrome floats over the day; opaque chrome sits above it.
  ///
  /// Those are two layouts, not one layout in two colours: the whole point of a
  /// translucent header is that the day passes underneath it, which means the
  /// day has to own the full height and hand the header back an inset
  /// (SPEC §9.8).
  Widget _body(BuildContext context) {
    final floats = PlatformStyle.from(context).glass;
    final header = DayHeader(
      onStop: _stop,
      onResumeLast: _resumeLast,
      onFixStart: _fixRunningStart,
    );
    // The panel is stacked over the day rather than above the bar, so opening
    // it costs calendar height and never squeezes the day header (SPEC §8.3).
    Widget day(double inset) => Stack(
      children: <Widget>[
        _DayBody(
          topInset: inset,
          onEntryTap: (entry) => showEntrySheet(context, entry),
          onPreviousDay: () =>
              ref.read(selectedDayProvider.notifier).previousDay(),
          onNextDay: () => ref.read(selectedDayProvider.notifier).nextDay(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: 0,
          child: StartSuggestionPanel(state: _composer, onPick: _startNamed),
        ),
      ],
    );

    if (!floats) {
      return Column(
        children: <Widget>[
          header,
          Expanded(child: day(0)),
        ],
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: day(_headerHeight)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Measured(
            onHeight: (height) {
              if (height != _headerHeight && mounted) {
                setState(() => _headerHeight = height);
              }
            },
            child: header,
          ),
        ),
      ],
    );
  }

  /// SPEC §9.2's "Fix start time…": open the entry whose start is wrong, which
  /// is where start times are edited. It used to open Settings, which could not
  /// fix anything.
  void _fixRunningStart() {
    final running = ref.read(runningEntryProvider).value;
    if (running != null) showEntrySheet(context, running);
  }

  /// A suggestion tap goes through the same action as the Start button, and
  /// leaves the composer at rest afterwards.
  Future<void> _startNamed(String name) async {
    _composer.reset();
    _screenFocus.requestFocus();
    await startActivityNamed(context, ref, name);
  }

  Future<void> _stop() async {
    final outcome = await ref.read(timelineWriterProvider).stop();
    if (!mounted || !outcome.stopped) return;
    showUndoableFeedback(
      context,
      message:
          'Stopped ${outcome.activityName} after '
          '${formatDurationVerbose(outcome.duration!)}',
      undo: outcome.undo,
      // Under a minute, the likelier intent is "that was a mistake", so offer
      // Discard in place of Undo (SPEC §6.2).
      extraAction: outcome.wasVeryShort
          ? SnackBarAction(
              label: 'Discard',
              onPressed: () =>
                  ref.read(timelineWriterProvider).delete(outcome.entryId!),
            )
          : null,
    );
  }

  Future<void> _resumeLast() async {
    final last = ref.read(lastFinishedEntryProvider).value;
    if (last == null) return;
    await resumeOrContinue(context, ref, last);
  }
}

/// Reports its child's height after every layout.
class _Measured extends StatefulWidget {
  const _Measured({required this.child, required this.onHeight});

  final Widget child;
  final ValueChanged<double> onHeight;

  @override
  State<_Measured> createState() => _MeasuredState();
}

class _MeasuredState extends State<_Measured> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) widget.onHeight(box.size.height);
    });
    return SizedBox(key: _key, child: widget.child);
  }
}

/// The macOS menu bar (SPEC §9.8, §10.5).
///
/// `PlatformMenuBar` renders only its child on every platform but macOS, where
/// it installs a real system menu. It lives inside TodayScreen rather than
/// above the router so that the items can call the very same methods the
/// keyboard shortcuts do -- a menu that drifts from its shortcuts is worse than
/// no menu -- and it stays installed while Settings is pushed on top, because
/// TodayScreen stays mounted underneath.
class _MenuBar extends ConsumerWidget {
  const _MenuBar({
    required this.child,
    required this.onStartSomething,
    required this.onStop,
    required this.onResumeLast,
    required this.onSettings,
  });

  final Widget child;
  final VoidCallback onStartSomething;
  final VoidCallback onStop;
  final VoidCallback onResumeLast;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only on macOS. `PlatformMenuBar` renders just its child elsewhere, but it
    // still *serialises* the menu first, and a PlatformProvidedMenuItem throws
    // when asked for an About entry on a platform that has no such thing.
    if (Theme.of(context).platform != TargetPlatform.macOS) return child;

    final day = ref.read(selectedDayProvider.notifier);
    final zoom = ref.read(calendarZoomProvider.notifier);

    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          // macOS replaces this label with the application's own name.
          label: 'time-log',
          menus: <PlatformMenuItem>[
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.about,
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Settings',
                  shortcut: commandActivator(LogicalKeyboardKey.comma),
                  onSelected: onSettings,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Track',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: 'Start something…',
              shortcut: commandActivator(LogicalKeyboardKey.keyN),
              onSelected: onStartSomething,
            ),
            PlatformMenuItem(
              label: 'Stop',
              shortcut: commandActivator(LogicalKeyboardKey.period),
              onSelected: onStop,
            ),
            PlatformMenuItem(
              label: 'Resume last',
              shortcut: commandActivator(LogicalKeyboardKey.keyR),
              onSelected: onResumeLast,
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Today',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyT),
                  onSelected: day.today,
                ),
                PlatformMenuItem(
                  label: 'Previous day',
                  shortcut: const SingleActivator(LogicalKeyboardKey.arrowLeft),
                  onSelected: day.previousDay,
                ),
                PlatformMenuItem(
                  label: 'Next day',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.arrowRight,
                  ),
                  onSelected: day.nextDay,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: 'Zoom in',
                  shortcut: commandActivator(LogicalKeyboardKey.equal),
                  onSelected: zoom.zoomIn,
                ),
                PlatformMenuItem(
                  label: 'Zoom out',
                  shortcut: commandActivator(LogicalKeyboardKey.minus),
                  onSelected: zoom.zoomOut,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}

/// The day itself. Horizontal swipe changes day; the arrows and date picker in
/// [DayNavigationBar] do the same without a gesture (SPEC §10.1).
class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.onEntryTap,
    required this.onPreviousDay,
    required this.onNextDay,
    this.topInset = 0,
  });

  final void Function(TimeEntry entry) onEntryTap;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(dayTimelineProvider);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 200) {
          onPreviousDay();
        } else if (velocity < -200) {
          onNextDay();
        }
      },
      // A day with no entries is one big empty axis, which tells the user
      // nothing. Say so in words instead.
      child: timeline.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: topInset),
              child: const _EmptyDay(),
            )
          : Stack(
              children: <Widget>[
                DayCalendar(onEntryTap: onEntryTap, topInset: topInset),
                // Over the day, not in the header: zoom acts on what is
                // underneath it (SPEC §8.2).
                Positioned(
                  top: topInset,
                  right: 0,
                  child: const CalendarZoomControl(),
                ),
              ],
            ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) => const _Notice(
    icon: Icons.schedule_outlined,
    title: 'No entries for this day',
    body: 'Type what you are doing in the field below.',
  );
}

/// The one way this app states something in the middle of an empty screen:
/// a tonal disc, a line of title, a line of explanation, and an optional
/// detail. Used by the empty day and by the database error so the two are
/// recognisably the same app.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.detail,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? detail;
  final _NoticeTone? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = tone == _NoticeTone.error;
    return Center(
      // Scrollable and bounded: an error can carry a very long message, and a
      // notice that overflows is no help to anyone.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHigh,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _NoticeTone { error }

/// SPEC §9.5: a database failure explains itself rather than showing an empty
/// timeline, which would read as data loss.
class _DatabaseError extends StatelessWidget {
  const _DatabaseError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // Also to the console, so a failure is diagnosable from a log rather than
    // only from the screen.
    debugPrint('time-log: the database could not be opened: $error');
    return _Notice(
      icon: Icons.error_outline,
      title: 'Your time log could not be opened.',
      body: 'Nothing has been lost; the app could not read its database.',
      detail: '$error',
      tone: _NoticeTone.error,
    );
  }
}
