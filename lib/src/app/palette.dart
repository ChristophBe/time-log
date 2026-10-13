import 'package:flutter/material.dart';

import '../core/color_contrast.dart';
import '../domain/models/activity.dart';

/// The colours one activity is drawn with.
@immutable
class ActivityColors {
  const ActivityColors({
    required this.fill,
    required this.onFill,
    required this.edge,
    required this.tint,
  });

  /// The body of a block: pale in light, deep in dark.
  final Color fill;

  /// Text drawn on [fill]. At least 4.5:1 against it (SPEC §10.3).
  final Color onFill;

  /// The saturated edge that carries the activity's identity: the spine down
  /// the left of a block, the dot beside a name in a list, the rule under the
  /// running band. At least 3:1 against [fill], so it reads as a deliberate
  /// edge and not as a slightly different shade of the same thing.
  final Color edge;

  /// A barely-there wash of the hue, for a surface that belongs to this
  /// activity without being a block: the running band, a highlighted row.
  final Color tint;
}

/// Twelve distinguishable hues for activities (SPEC §9.7).
///
/// These are the only saturated colours in the app. The chrome around them is
/// near-neutral on purpose (`theme.dart`), so colour on screen always means
/// "this is that activity" and never just "this is a button".
///
/// Every colour is built by solving for a **target relative luminance** rather
/// than by picking an HSL lightness, because luminance is what contrast is
/// computed from. That turns SPEC §10.3 from something to re-check whenever a
/// hue is added into something true by construction: the fill/text pairing
/// clears 4.5:1 and the fill/edge pairing clears 3:1 for *any* hue, and
/// neighbouring slots alternate between two luminance tiers so two activities
/// created one after the other stay distinct in grayscale and under a
/// deuteranopia simulation, where the hue step gives nothing.
abstract final class ActivityPalette {
  /// The arc that belongs to the app, not to any activity.
  ///
  /// The live accent (`theme.dart`) sits in here and means *now*. Striking the
  /// arc from the palette is what makes that reading unambiguous: a vivid
  /// indigo on screen is the now-line or a focus ring, never "the activity
  /// someone named indigo" (SPEC §9.8). Asserted in `palette_test.dart`.
  static const double reservedHueStart = 215;
  static const double reservedHueEnd = 277;

  /// Twelve hues: spread round the wheel outside the reserved arc, then ordered
  /// so that each is far from the one before it.
  ///
  /// Three decisions are packed in here. The *set* is spread rather than evenly
  /// stepped, because an even 30-degree walk spends four of the twelve slots on
  /// reds and pinks, which are the hardest pairs to tell apart — the
  /// three-reds-in-a-row of the first version was exactly that mistake. It
  /// *avoids the reserved arc*, at a cost worth naming: the blues stop at 214
  /// and resume at 278, so the palette has one blue rather than three. The
  /// *order* matters because activities take the least-used slot in order
  /// (SPEC §9.7), so slots 0 and 1 are the two colours a new user sees side by
  /// side: consecutive slots are far apart, and the first is a calm blue rather
  /// than a red, which on a running band reads as an alarm.
  static const List<double> hues = <double>[
    214, // blue
    28, // orange
    134, // emerald
    320, // magenta
    46, // amber
    192, // cyan
    278, // violet
    96, // green
    6, // red
    166, // teal
    68, // yellow-green
    115, // leaf
  ];

  static int get length => Activity.colorSeedCount;

  // Target luminances. Two tiers per role, alternating by slot.
  static const List<double> _lightFill = <double>[0.80, 0.72];
  static const List<double> _darkFill = <double>[0.045, 0.075];
  static const double _lightText = 0.05;
  static const double _darkText = 0.70;
  static const double _lightEdge = 0.17;
  static const double _darkEdge = 0.38;
  static const double _lightTint = 0.90;
  static const double _darkTint = 0.025;

  // Saturations. Fills stay muted so twelve of them in a column read as one
  // family; edges are saturated because their whole job is to be legible at
  // three pixels wide.
  static const double _fillSat = 0.50;
  static const double _fillSatDark = 0.42;
  static const double _textSat = 0.65;
  static const double _edgeSat = 0.75;
  static const double _tintSat = 0.35;

  static ActivityColors forSeed(int seed, Brightness brightness) {
    final slot = seed.remainder(length).abs();
    final hue = hues[slot];
    final tier = slot.isEven ? 0 : 1;
    final dark = brightness == Brightness.dark;

    return ActivityColors(
      fill: _atLuminance(
        hue,
        dark ? _fillSatDark : _fillSat,
        dark ? _darkFill[tier] : _lightFill[tier],
      ),
      onFill: _atLuminance(hue, _textSat, dark ? _darkText : _lightText),
      edge: _atLuminance(hue, _edgeSat, dark ? _darkEdge : _lightEdge),
      tint: _atLuminance(hue, _tintSat, dark ? _darkTint : _lightTint),
    );
  }

  /// The colour of [hue] at [saturation] whose relative luminance is [target].
  ///
  /// Relative luminance rises monotonically with HSL lightness at a fixed hue
  /// and saturation, so a bisection always converges; twenty steps put it well
  /// inside a single 8-bit channel value.
  static Color _atLuminance(double hue, double saturation, double target) {
    var low = 0.0;
    var high = 1.0;
    var colour = HSLColor.fromAHSL(1, hue, saturation, 0.5).toColor();
    for (var i = 0; i < 20; i++) {
      final mid = (low + high) / 2;
      colour = HSLColor.fromAHSL(1, hue, saturation, mid).toColor();
      if (relativeLuminance(colour) < target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return colour;
  }

  /// Delegates to [Activity.nextColorSeed]; allocation is domain logic, the
  /// hues are presentation.
  static int nextSeed(Iterable<int> usedSeeds) =>
      Activity.nextColorSeed(usedSeeds);
}
