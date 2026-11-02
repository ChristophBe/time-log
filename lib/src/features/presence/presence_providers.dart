import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../data/repositories/active_session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/presence/active_session.dart';
import '../today/today_providers.dart';
import 'presence_controller.dart';
import 'presence_port.dart';

part 'presence_providers.g.dart';

/// The selected day's active sessions, oldest first (SPEC §9.9).
@riverpod
Stream<List<ActiveSession>> daySessions(Ref ref) {
  final window = ref.watch(selectedDayProvider);
  return ref
      .watch(activeSessionRepositoryProvider)
      .watchRange(window.startUtc, window.endUtc);
}

/// The selected day's active total, or null on a day without any sessions, so
/// the header can leave it out altogether (SPEC §8.1).
///
/// On the same 30-second tick as the tracked total beside it.
@riverpod
Duration? activeTotal(Ref ref) {
  final sessions =
      ref.watch(daySessionsProvider).value ?? const <ActiveSession>[];
  if (sessions.isEmpty) return null;
  final window = ref.watch(selectedDayProvider);
  return computeActiveTotal(
    sessions: sessions,
    from: window.startUtc,
    to: window.endUtc,
    now:
        ref.watch(coarseTickerProvider).value ??
        ref.watch(appClockProvider).nowUtc(),
  );
}

/// Asked again whenever the setting changes, once the change has landed.
@riverpod
Future<LoginItemStatus> loginItemStatus(Ref ref) async {
  ref.watch(appSettingsProvider);
  await ref.watch(presenceControllerProvider).settled;
  return ref.watch(presencePortProvider).loginItemStatus();
}
