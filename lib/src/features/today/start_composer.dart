import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/glass.dart';
import '../../app/palette.dart';
import '../../app/platform_style.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../core/formatters.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_settings.dart';
import 'start_action.dart';
import 'today_providers.dart';

/// The state the composer's two halves share.
///
/// They are separate widgets in separate parts of the Scaffold -- the bar in
/// `bottomNavigationBar`, the panel over the calendar -- so what was typed, what
/// has focus and which row is highlighted has to live above both. Owned and
/// disposed by `TodayScreen`.
class StartComposerState {
  StartComposerState()
    : text = TextEditingController(),
      focus = FocusNode(debugLabel: 'start composer'),
      highlighted = ValueNotifier<int>(-1);

  final TextEditingController text;
  final FocusNode focus;

  /// Which suggestion Enter would pick. -1 means "use what is typed".
  final ValueNotifier<int> highlighted;

  /// Rebuilds anything that cares about any of the three.
  Listenable get listenable =>
      Listenable.merge(<Listenable>[text, focus, highlighted]);

  /// The suggestion panel is only worth its space once the user has shown
  /// interest; at rest the day gets the screen.
  bool get isActive => focus.hasFocus || text.text.isNotEmpty;

  String get query => text.text;

  String get typedName => text.text.trim();

  void reset() {
    text.clear();
    highlighted.value = -1;
  }

  void dispose() {
    text.dispose();
    focus.dispose();
    highlighted.dispose();
  }
}

/// The field and the Start button, docked to the bottom of Today
/// (SPEC §8.1, §8.3).
///
/// It is not a sheet. The app has exactly one primary verb, so the control that
/// performs it sits in the open rather than behind a button that opens a modal
/// containing it. Docking it at the bottom also puts the suggestion list
/// *above* the soft keyboard instead of behind it, which is what the modal got
/// wrong.
class StartComposerBar extends ConsumerStatefulWidget {
  const StartComposerBar({
    required this.state,
    required this.onRelease,
    super.key,
  });

  final StartComposerState state;

  /// Called when the field lets go, so the screen can take focus back. Plain
  /// `unfocus()` is not enough: it leaves focus outside the subtree carrying
  /// the day-view shortcuts, which would make them dead after the first thing
  /// you typed (SPEC §10.5).
  final VoidCallback onRelease;

  @override
  ConsumerState<StartComposerBar> createState() => _StartComposerBarState();
}

class _StartComposerBarState extends ConsumerState<StartComposerBar> {
  /// A physical Enter fires both `onSubmitted` and the raw key event, and a
  /// double tap on a row arrives twice. Either would start twice.
  bool _starting = false;

  StartComposerState get _state => widget.state;

  Future<void> _start(String name) async {
    if (_starting) return;
    _starting = true;
    // Reset first: the field should be empty the instant it is committed, not
    // after the write round-trips.
    _state.reset();
    widget.onRelease();
    try {
      await startActivityNamed(context, ref, name);
    } finally {
      _starting = false;
    }
  }

  void _submitTyped() {
    final name = _state.typedName;
    if (!Activity.isValidName(name)) return;
    _start(name);
  }

  KeyEventResult _onKey(List<ActivitySuggestion> suggestions, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final highlighted = _state.highlighted;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        highlighted.value = suggestions.isEmpty
            ? -1
            : (highlighted.value + 1).clamp(0, suggestions.length - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        highlighted.value = highlighted.value <= 0 ? -1 : highlighted.value - 1;
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // There is no modal to dismiss any more, so Escape abandons what was
        // typed and hands the screen back to the day.
        _state.reset();
        widget.onRelease();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (highlighted.value >= 0 && highlighted.value < suggestions.length) {
          _start(suggestions[highlighted.value].activity.name);
        } else {
          _submitTyped();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _state.listenable,
    builder: (context, _) {
      final suggestions =
          ref.watch(activitySuggestionsProvider(_state.query)).value ??
          const <ActivitySuggestion>[];
      final canStart = Activity.isValidName(_state.text.text);

      return Shortcuts(
        // TodayScreen binds bare T and the horizontal arrows to day navigation
        // (SPEC §10.5). Those keys bubble out of a focused text field, so
        // without this the arrows would change the day instead of moving the
        // caret and typing a "t" would jump to today. The field still receives
        // the key -- DoNothingAndStopPropagationIntent only stops the climb.
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyT):
              DoNothingAndStopPropagationIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              DoNothingAndStopPropagationIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              DoNothingAndStopPropagationIntent(),
        },
        child: GlassSurface(
          edge: GlassEdge.top,
          child: Material(
            // One surface for the whole screen, divided by a hairline rather
            // than by a change of tone — and on Apple by the glass itself,
            // which brings its own lit edge (SPEC §9.8).
            color: PlatformStyle.from(context).glass
                ? Colors.transparent
                : Theme.of(context).colorScheme.surface,
            shape: PlatformStyle.from(context).glass
                ? null
                : Border(
                    top: BorderSide(
                      color: AppColors.from(context).hairline,
                      width: Strokes.hairline,
                    ),
                  ),
            child: SafeArea(
              top: false,
              child: Padding(
                // Scaffold does not lift bottomNavigationBar over the soft
                // keyboard, so the bar lifts itself. Padding rather than
                // position, so the slot grows too and the SnackBar keeps clear.
                padding: EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  Insets.sm + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Focus(
                        onKeyEvent: (_, event) => _onKey(suggestions, event),
                        child: TextField(
                          key: const Key('start-field'),
                          controller: _state.text,
                          focusNode: _state.focus,
                          textInputAction: TextInputAction.go,
                          maxLength: Activity.maxNameLength,
                          decoration: const InputDecoration(
                            labelText: 'What now?',
                            hintText: 'Type what you are doing',
                            // The field is the only control here; a character
                            // counter under it would just add a line of noise.
                            counterText: '',
                          ),
                          onChanged: (_) => _state.highlighted.value = -1,
                          onSubmitted: (_) => _submitTyped(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    // Pressing Start on a name that matches nothing creates it,
                    // so creation is never a mode (SPEC §8.3).
                    FilledButton.icon(
                      key: const Key('start-button'),
                      onPressed: canStart ? _submitTyped : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The ranked suggestions, rising over the calendar while the field is in use
/// (SPEC §8.3, §9.6).
///
/// Lives in the body rather than stacked on the bar so that opening it costs
/// calendar height and nothing else. Inside the bar it would grow
/// `bottomNavigationBar`, squeezing the running card and the day header out of
/// the Scaffold body — which overflows at large text scales (SPEC §10.2).
class StartSuggestionPanel extends ConsumerWidget {
  const StartSuggestionPanel({
    required this.state,
    required this.onPick,
    super.key,
  });

  final StartComposerState state;
  final void Function(String name) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedBuilder(
    animation: state.listenable,
    builder: (context, _) {
      // Built unconditionally and switched, rather than returned early: the
      // panel covers the day, and something that covers the day should be seen
      // to arrive and to leave. AnimatedSwitcher gives it both ends for free,
      // and Motion.of returns zero when the platform asks for no animation
      // (SPEC §10.2).
      return AnimatedSwitcher(
        duration: Motion.of(context, Motion.short),
        switchInCurve: Motion.curve,
        switchOutCurve: Motion.curve,
        child: state.isActive
            ? _panel(context, ref)
            : const SizedBox.shrink(key: ValueKey<String>('no-panel')),
      );
    },
  );

  Widget _panel(BuildContext context, WidgetRef ref) {
    final suggestions =
        ref.watch(activitySuggestionsProvider(state.query)).value ??
        const <ActivitySuggestion>[];
    final running = ref.watch(runningEntryProvider).value;
    final activities =
        ref.watch(activitiesByIdProvider).value ?? const <String, Activity>{};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final now = ref.watch(appClockProvider).nowUtc();
    final isTyping = state.typedName.isNotEmpty;

    final scheme = Theme.of(context).colorScheme;

    return Stack(
      key: const ValueKey<String>('panel'),
      children: <Widget>[
        // Dims the day while the panel is up, so the list reads as the thing
        // in hand. Not tappable: a tap-to-dismiss scrim is an unlabelled tap
        // target (SPEC §10.4), and Escape already hands the screen back.
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: AppColors.from(context).scrim),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          // Over the day and over a scrim: the one surface in the app with the
          // most behind it, so the one that gains most from being glass.
          child: GlassSurface(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(PlatformStyle.from(context).sheetRadius),
            ),
            edge: GlassEdge.top,
            opacity: 0.86,
            child: Material(
              color: PlatformStyle.from(context).glass
                  ? Colors.transparent
                  : scheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              // Edge, not shadow: over a scrim a drop shadow reads as a black
              // line drawn along the top of the panel.
              shape: RoundedRectangleBorder(
                borderRadius: Radii.lgTop,
                side: PlatformStyle.from(context).glass
                    ? BorderSide.none
                    : BorderSide(
                        color: AppColors.from(context).hairline,
                        width: Strokes.hairline,
                      ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Flexible(
                    child: suggestions.isEmpty
                        // Nothing to rank. Worth saying so on a fresh install,
                        // where an empty panel would look broken (SPEC §9.6) --
                        // but not while a name is being typed, where it would
                        // be telling the user to do what they are already
                        // doing.
                        ? (isTyping
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.lg,
                                    vertical: Insets.xl,
                                  ),
                                  child: Text(
                                    'Type what you are doing to start '
                                    'tracking it.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ))
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                              vertical: Insets.sm,
                            ),
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) =>
                                ValueListenableBuilder<int>(
                                  valueListenable: state.highlighted,
                                  builder: (context, highlighted, _) =>
                                      _SuggestionRow(
                                        suggestion: suggestions[index],
                                        highlighted: index == highlighted,
                                        now: now,
                                        onTap: () => onPick(
                                          suggestions[index].activity.name,
                                        ),
                                      ),
                                ),
                          ),
                  ),
                  if (running != null)
                    _ConsequenceLine(
                      // The one and only warning before switching; Undo covers
                      // the rest (SPEC §8.3). It sits at the bottom of the
                      // panel, directly above the field, so the cause is next
                      // to the effect.
                      text:
                          'Stops '
                          '${activities[running.activityId]?.name ?? 'the current activity'} '
                          'at ${formatTimeOfDay(now.toLocal(), use24h: settings.use24HourClock)}.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What pressing Start is about to do to whatever is running.
class _ConsequenceLine extends StatelessWidget {
  const _ConsequenceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: AppColors.from(context).hairline,
            width: Strokes.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.sm,
        Insets.lg,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.swap_horiz_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.now,
    required this.onTap,
  });

  final ActivitySuggestion suggestion;
  final bool highlighted;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ActivityPalette.forSeed(
      suggestion.activity.colorSeed,
      Theme.of(context).brightness,
    );
    final last = suggestion.lastUsed;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        // Highlight by surface, not by recolouring the name: the row's colour
        // belongs to its activity, and tinting the text would make two things
        // compete to say which row Enter would take.
        color: highlighted ? scheme.secondaryContainer : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: Metrics.colorDot,
              height: Metrics.colorDot,
              decoration: BoxDecoration(
                color: colors.edge,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                suggestion.activity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (last != null) ...<Widget>[
              const SizedBox(width: Insets.sm),
              Text(
                '${formatAge(now.difference(last))} ago',
                maxLines: 1,
                style: AppType.numeric(Theme.of(context).textTheme.labelSmall)
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
