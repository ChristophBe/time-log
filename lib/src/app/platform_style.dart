import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design.dart';

/// Which design system's manners the app is using.
enum PlatformIdiom {
  /// iOS and macOS: continuous corners, grouped lists, wheel pickers.
  apple,

  /// Android, and the fallback for anything unrecognised.
  material,

  /// Windows: tight corners, dense controls.
  fluent,

  /// Linux desktops: GNOME's libadwaita is the reference.
  gnome,
}

/// The handful of numbers a design system actually dictates.
///
/// This is the counterpart to `design.dart`, and the split between them is the
/// point: `Insets`, `Radii` and `AppType` are the app's *identity* and are the
/// same on every platform, while this is its *manners* and changes with the
/// platform it is a guest on. Colour meaning, typeface and the calendar's own
/// shapes are deliberately not in here (SPEC §9.8).
///
/// Chosen from [defaultTargetPlatform], which `flutter test` pins to Android —
/// so the whole existing suite exercises the Material values, and the others
/// are reached with `debugDefaultTargetPlatformOverride`.
@immutable
class PlatformStyle {
  const PlatformStyle({
    required this.idiom,
    required this.controlRadius,
    required this.containerRadius,
    required this.sheetRadius,
    required this.buttonHeight,
    required this.pillButtons,
    required this.compact,
    required this.centredTitle,
    required this.sheetDragHandle,
    this.glass = false,
  });

  final PlatformIdiom idiom;

  /// Buttons, fields, blocks.
  final double controlRadius;

  /// Grouped containers and cards.
  final double containerRadius;

  /// The top corners of a sheet or the suggestion panel.
  final double sheetRadius;

  /// Visual height of a button. Never the tap target, which stays at least
  /// 48 dp everywhere (SPEC §10.2) — a dense desktop button still has room
  /// around it to be hit.
  final double buttonHeight;

  /// Material wants a stadium; the others want a rectangle with corners.
  final bool pillButtons;

  /// Desktops are pointer-first and expect more on screen at once.
  final bool compact;

  /// iOS centres a navigation title; GNOME centres its header bar title.
  final bool centredTitle;

  /// Material's bottom sheet announces itself with a drag handle. An Apple
  /// sheet is inset and rounded and does not need one.
  final bool sheetDragHandle;

  /// Whether chrome is made of Liquid Glass: translucent, blurred, floating
  /// over the content rather than beside it (SPEC §9.8). Apple only.
  final bool glass;

  bool get isApple => idiom == PlatformIdiom.apple;

  OutlinedBorder get buttonShape => pillButtons
      ? const StadiumBorder()
      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        );

  VisualDensity get density =>
      compact ? VisualDensity.compact : VisualDensity.standard;

  static const PlatformStyle material = PlatformStyle(
    idiom: PlatformIdiom.material,
    controlRadius: 10,
    containerRadius: 14,
    sheetRadius: 24,
    buttonHeight: 44,
    pillButtons: true,
    compact: false,
    centredTitle: false,
    sheetDragHandle: true,
  );

  /// Liquid Glass, as of iOS 26 and macOS Tahoe: capsule controls, markedly
  /// rounder containers, and chrome that floats over the content as a
  /// translucent material rather than sitting beside it in its own band.
  ///
  /// Apple's corners are continuous curves rather than circular arcs. Flutter's
  /// `ContinuousRectangleBorder` is a poor approximation of one, so the nearer
  /// miss is a circular corner at Apple's own radii.
  static const PlatformStyle apple = PlatformStyle(
    idiom: PlatformIdiom.apple,
    controlRadius: 12,
    containerRadius: 18,
    sheetRadius: 28,
    buttonHeight: 44,
    pillButtons: true,
    compact: false,
    centredTitle: true,
    sheetDragHandle: false,
    glass: true,
  );

  static const PlatformStyle fluent = PlatformStyle(
    idiom: PlatformIdiom.fluent,
    controlRadius: 4,
    containerRadius: 6,
    sheetRadius: 8,
    buttonHeight: 32,
    pillButtons: false,
    compact: true,
    centredTitle: false,
    sheetDragHandle: false,
  );

  static const PlatformStyle gnome = PlatformStyle(
    idiom: PlatformIdiom.gnome,
    controlRadius: 8,
    containerRadius: 12,
    sheetRadius: 14,
    buttonHeight: 36,
    pillButtons: false,
    compact: true,
    centredTitle: true,
    sheetDragHandle: false,
  );

  static PlatformStyle of(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => apple,
    TargetPlatform.windows => fluent,
    TargetPlatform.linux => gnome,
    TargetPlatform.android || TargetPlatform.fuchsia => material,
  };

  /// macOS is Apple-flavoured but a desktop: pointer-first, and its windows are
  /// dense. The phone values are otherwise right for it.
  static PlatformStyle forCurrent() {
    final style = of(defaultTargetPlatform);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return style.copyWith(compact: true, centredTitle: false);
    }
    return style;
  }

  PlatformStyle copyWith({bool? compact, bool? centredTitle}) => PlatformStyle(
    glass: glass,
    idiom: idiom,
    controlRadius: controlRadius,
    containerRadius: containerRadius,
    sheetRadius: sheetRadius,
    buttonHeight: buttonHeight,
    pillButtons: pillButtons,
    compact: compact ?? this.compact,
    centredTitle: centredTitle ?? this.centredTitle,
    sheetDragHandle: sheetDragHandle,
  );

  /// The style the surrounding theme was built with.
  static PlatformStyle from(BuildContext context) =>
      PlatformStyle.of(Theme.of(context).platform);
}

/// How much a platform's own shape differs from the identity scale, for the
/// places that read [Radii] directly.
extension PlatformRadii on PlatformStyle {
  BorderRadius get controlBorderRadius => BorderRadius.circular(controlRadius);
  BorderRadius get containerBorderRadius =>
      BorderRadius.circular(containerRadius);
  BorderRadius get sheetBorderRadius =>
      BorderRadius.vertical(top: Radius.circular(sheetRadius));

  /// Identity shapes that do not move: the calendar's own blocks keep the app's
  /// radius wherever they are drawn (SPEC §9.8).
  BorderRadius get blockRadius => Radii.smAll;
}
