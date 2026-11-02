import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/active_session_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'presence_port.dart';

part 'presence_controller.g.dart';

/// How often the open session is stamped, and the platform asked again
/// (SPEC §9.9, rule 4).
const Duration heartbeatInterval = Duration(seconds: 60);

/// Follows the setting, and feeds what the platform says into the repository.
///
/// Everything here runs on signals and a timer rather than on a screen, so it
/// keeps going with the window closed. A failure is logged and left for the next
/// heartbeat: nothing about active time is worth interrupting the app for.
class PresenceController {
  PresenceController({
    required PresencePort port,
    required ActiveSessionRepository Function() sessions,
  }) // Named parameters cannot be private, so initializing formals are not an
    // option for these fields.
    // ignore: prefer_initializing_formals
    : _port = port,
       // ignore: prefer_initializing_formals
       _sessions = sessions;

  final PresencePort _port;
  final ActiveSessionRepository Function() _sessions;

  StreamSubscription<Object?>? _signals;
  Timer? _heartbeat;
  bool? _enabled;
  Future<void> _settled = Future<void>.value();

  /// Done once the last [sync] has reached the platform.
  Future<void> get settled => _settled;

  /// Brings recording in line with the setting.
  ///
  /// The first call just reports what was stored at launch. Only a later change
  /// is the user flipping the switch, and only that touches the login item.
  void sync({required bool enabled}) {
    final previous = _enabled;
    if (previous == enabled) return;
    _enabled = enabled;
    final userChanged = previous != null;
    _settled = _settled.then(
      (_) => _guard(() async {
        if (enabled) {
          await _start(updateLoginItem: userChanged);
        } else if (userChanged) {
          await _stop();
        }
      }),
    );
  }

  /// One heartbeat. Stamping first means a session gone stale ends where it was
  /// last seen, and the platform's answer then opens a fresh one if that is the
  /// truth. This re-read is also what catches a lock no notification reported.
  Future<void> beat() => _guard(() async {
    await _sessions().heartbeat();
    await _sessions().apply(await _port.currentState());
  });

  Future<void> dispose() async {
    _heartbeat?.cancel();
    await _signals?.cancel();
  }

  Future<void> _start({required bool updateLoginItem}) async {
    _signals ??= _port.signals.listen(
      (signal) => unawaited(_guard(() => _sessions().apply(signal))),
      onError: (Object error) => debugPrint('time-log: presence: $error'),
    );
    await _port.setTracking(enabled: true, updateLoginItem: updateLoginItem);
    await beat();
    _heartbeat ??= Timer.periodic(heartbeatInterval, (_) => unawaited(beat()));
  }

  Future<void> _stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _signals?.cancel();
    _signals = null;
    await _sessions().stop();
    await _port.setTracking(enabled: false, updateLoginItem: true);
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (error) {
      debugPrint('time-log: presence: $error');
    }
  }
}

@Riverpod(keepAlive: true)
PresenceController presenceController(Ref ref) {
  final port = ref.watch(presencePortProvider);
  final controller = PresenceController(
    port: port,
    // Lazily, so a platform without presence never opens the database for it.
    sessions: () => ref.read(activeSessionRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  if (port.isSupported) {
    ref.listen(appSettingsProvider, fireImmediately: true, (_, settings) {
      final enabled = settings.value?.trackActiveTime;
      if (enabled != null) controller.sync(enabled: enabled);
    });
  }
  return controller;
}
