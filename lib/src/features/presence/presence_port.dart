import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/presence/active_session.dart';
import '../../domain/presence/presence_rules.dart';

part 'presence_port.g.dart';

/// Where the app stands as a login item (SPEC §9.9).
enum LoginItemStatus {
  enabled,

  /// Registered, but the user has to allow it in System Settings.
  requiresApproval,
  notRegistered,
  unavailable,
}

/// What the platform can tell the app about the person at the computer.
///
/// A port for the same reason the backup source is one: a test needs to say
/// "the screen just locked" without there being a screen.
abstract interface class PresencePort {
  bool get isSupported;

  Stream<PresenceSignal> get signals;

  /// The state of the computer right now.
  Future<PresenceSignal> currentState();

  /// Turns recording on or off. [updateLoginItem] is true only when the user
  /// flipped the switch: re-registering on every launch would argue with them
  /// after they had removed the app in System Settings.
  Future<void> setTracking({
    required bool enabled,
    required bool updateLoginItem,
  });

  Future<LoginItemStatus> loginItemStatus();

  Future<void> openLoginItemSettings();
}

/// Everywhere but macOS, for now (SPEC §9.9).
class UnsupportedPresencePort implements PresencePort {
  const UnsupportedPresencePort();

  @override
  bool get isSupported => false;

  @override
  Stream<PresenceSignal> get signals => const Stream<PresenceSignal>.empty();

  @override
  Future<PresenceSignal> currentState() =>
      throw UnsupportedError('No presence on this platform');

  @override
  Future<void> setTracking({
    required bool enabled,
    required bool updateLoginItem,
  }) async {}

  @override
  Future<LoginItemStatus> loginItemStatus() async =>
      LoginItemStatus.unavailable;

  @override
  Future<void> openLoginItemSettings() async {}
}

/// `macos/Runner/PresenceMonitor.swift`.
class MacOsPresencePort implements PresencePort {
  const MacOsPresencePort();

  static const _methods = MethodChannel('time_log/presence');
  static const _events = EventChannel('time_log/presence/events');

  @override
  bool get isSupported => true;

  @override
  Stream<PresenceSignal> get signals => _events.receiveBroadcastStream().map(
    (event) =>
        _signal((event as Map<Object?, Object?>).cast<String, Object?>()),
  );

  @override
  Future<PresenceSignal> currentState() async => _signal(
    (await _methods.invokeMapMethod<String, Object?>('currentState'))!,
  );

  @override
  Future<void> setTracking({
    required bool enabled,
    required bool updateLoginItem,
  }) => _methods.invokeMethod<void>('setTracking', <String, Object?>{
    'enabled': enabled,
    'updateLoginItem': updateLoginItem,
  });

  @override
  Future<LoginItemStatus> loginItemStatus() async {
    final name = await _methods.invokeMethod<String>('loginItemStatus');
    return LoginItemStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => LoginItemStatus.unavailable,
    );
  }

  @override
  Future<void> openLoginItemSettings() =>
      _methods.invokeMethod<void>('openLoginItemSettings');

  /// Instants are taken natively, so a signal delivered late by a Mac that was
  /// busy waking up still says when it happened.
  static PresenceSignal _signal(Map<String, Object?> map) {
    final at = DateTime.fromMillisecondsSinceEpoch(
      (map['atMillis']! as num).toInt(),
      isUtc: true,
    );
    if (map['active'] == true) return PresenceSignal.active(at);
    return PresenceSignal.inactive(
      SessionEndReason.fromName(map['reason'] as String?) ??
          SessionEndReason.sleep,
      at,
    );
  }
}

@Riverpod(keepAlive: true)
PresencePort presencePort(Ref ref) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
    ? const MacOsPresencePort()
    : const UnsupportedPresencePort();
