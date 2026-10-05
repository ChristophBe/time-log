import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The command key, as the platform means it.
///
/// SPEC §10.5 writes the shortcuts as "Cmd/Ctrl + N" because that is one
/// shortcut with two names, not two shortcuts. Registering both on every
/// platform — which is what this app used to do — means Ctrl+N fires on a Mac,
/// where Ctrl+N is a text-navigation key.
SingleActivator commandActivator(
  LogicalKeyboardKey key, {
  bool shift = false,
}) => _isApple
    ? SingleActivator(key, meta: true, shift: shift)
    : SingleActivator(key, control: true, shift: shift);

/// How to say the command key in a menu or a help sheet.
String get commandKeyLabel => _isApple ? 'Cmd' : 'Ctrl';

bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;
