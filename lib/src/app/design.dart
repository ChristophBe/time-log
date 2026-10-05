import 'package:flutter/material.dart';

/// The spacing, shape and motion scale.
///
/// Every padding, radius and stroke width in the app comes from here. The point
/// is not the particular numbers but that there is one set of them: a screen
/// built from 12s and 16s and 6s picked per widget reads as parts bolted
/// together, which is exactly what this file exists to stop.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Three sizes, by role: controls and blocks, containers, sheets.
///
/// Buttons are not in the list: they are pills (see [Radii.pill]), because a
/// button is the one thing on screen that should look like it can be pressed.
abstract final class Radii {
  /// Calendar blocks, fields, small surfaces.
  static const Radius sm = Radius.circular(10);

  /// Grouped containers and cards.
  static const Radius md = Radius.circular(14);

  /// Sheets and the suggestion panel: the big surfaces that slide in.
  static const Radius lg = Radius.circular(24);

  static const BorderRadius smAll = BorderRadius.all(sm);
  static const BorderRadius mdAll = BorderRadius.all(md);
  static const BorderRadius lgTop = BorderRadius.vertical(top: lg);

  /// For pills, where the radius should always be half the height.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Line weights.
abstract final class Strokes {
  /// Dividers, hour rules, the gutter spine.
  static const double hairline = 1;

  /// The coloured edge that carries an activity's identity on a block.
  static const double spine = 4;

  /// Focus and selection rings. 2 is the Material default and ≥ 3:1 by theme.
  static const double focus = 2;

  /// The now-line.
  static const double now = 2;
}

/// Durations and curves, for the few things that move.
///
/// Honour [MediaQuery.disableAnimationsOf] at the call site: SPEC §10.2 asks for
/// no motion at all when the platform asks for none.
abstract final class Motion {
  /// A state change on something already on screen: a selection ring.
  static const Duration quick = Duration(milliseconds: 90);
  static const Duration short = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;

  /// [d], or zero if the platform has asked for no animation.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// The two voices (SPEC §9.8).
///
/// Words are set in the sans and every number in the mono: the hour axis, the
/// times on a block, durations, totals, the age beside a suggestion, and the
/// ticking readout. They are one designed superfamily, so the two voices are
/// relatives rather than strangers, and the mono's figures are the same width
/// by construction — a clock that does not shift as its digits change.
///
/// Which strings are numbers is a judgement the call site makes, so this is a
/// helper rather than a set of styles: [numeric] takes any style from the text
/// theme and says it in the other voice.
abstract final class AppType {
  static const String sans = 'Geist';
  static const String mono = 'GeistMono';

  /// [base], re-set in the mono.
  static TextStyle? numeric(TextStyle? base) => base?.copyWith(
    fontFamily: mono,
    // The mono is wider than the sans at the same size; a touch of negative
    // tracking keeps a time range from out-running its block.
    letterSpacing: -0.2,
  );
}

/// Sizes that are layout decisions rather than spacing.
/// The smallest thing a finger can be asked to hit (SPEC §10.2).
const double kMinTapTarget = 48;

abstract final class Metrics {
  /// Height of the running band, in all three of its states, so the header
  /// never changes height when something starts or stops (SPEC §8.1).
  static const double runningBand = 64;

  /// Calendar axis gutter, before text scaling is applied.
  static const double gutterBase = 56;
  static const double gutterMax = 140;

  /// The label column in the entry sheet's time fields.
  static const double fieldLabel = 88;

  /// Diameter of the colour dot that identifies an activity in a list.
  static const double colorDot = 12;
}
