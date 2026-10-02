import 'package:flutter/material.dart';

/// The activity colour pair for one block: its fill and the text drawn on it.
@immutable
class ActivityColors {
  const ActivityColors({required this.fill, required this.onFill});

  final Color fill;
  final Color onFill;
}

/// Twelve distinguishable hues for activities (SPEC §9.7).
///
/// Fill and text lightness are fixed per brightness, which is what guarantees
/// the 4.5:1 contrast of SPEC §10.3 for every hue instead of only for the ones
/// someone happened to check. Colour is never the only signal -- every block
/// also carries its name as text (SPEC §10.3).
abstract final class ActivityPalette {
  /// Evenly spread hues, nudged off pure primaries so adjacent ones stay
  /// distinguishable for the common colour-vision deficiencies.
  static const List<double> hues = <double>[
    4,
    32,
    50,
    92,
    150,
    172,
    196,
    220,
    258,
    286,
    320,
    342,
  ];

  static const int length = 12;

  // Light theme: pale fill, near-black text. Dark theme: deep fill, near-white text.
  static const double _lightFill = 0.86;
  static const double _lightText = 0.22;
  static const double _darkFill = 0.26;
  static const double _darkText = 0.92;

  static ActivityColors forSeed(int seed, Brightness brightness) {
    final hue = hues[seed.remainder(length).abs()];
    final dark = brightness == Brightness.dark;
    return ActivityColors(
      fill: HSLColor.fromAHSL(
        1,
        hue,
        dark ? 0.42 : 0.62,
        dark ? _darkFill : _lightFill,
      ).toColor(),
      onFill: HSLColor.fromAHSL(
        1,
        hue,
        dark ? 0.30 : 0.70,
        dark ? _darkText : _lightText,
      ).toColor(),
    );
  }

  /// The seed to give a new activity: the least-used slot, lowest index winning
  /// ties so the first twelve activities each get their own hue.
  static int nextSeed(Iterable<int> usedSeeds) {
    final counts = List<int>.filled(length, 0);
    for (final s in usedSeeds) {
      counts[s.remainder(length).abs()]++;
    }
    var best = 0;
    for (var i = 1; i < length; i++) {
      if (counts[i] < counts[best]) best = i;
    }
    return best;
  }
}
