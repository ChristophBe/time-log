import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/app/palette.dart';
import 'package:time_log/src/core/color_contrast.dart';

void main() {
  test('every palette hue meets 4.5:1 text contrast in both themes', () {
    for (var seed = 0; seed < ActivityPalette.length; seed++) {
      for (final brightness in Brightness.values) {
        final colors = ActivityPalette.forSeed(seed, brightness);
        final ratio = contrastRatio(colors.fill, colors.onFill);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              'SPEC §10.3: seed $seed in $brightness is only '
              '${ratio.toStringAsFixed(2)}:1',
        );
      }
    }
  });

  test('seeds wrap rather than throwing on out-of-range input', () {
    expect(
      ActivityPalette.forSeed(ActivityPalette.length, Brightness.light).fill,
      ActivityPalette.forSeed(0, Brightness.light).fill,
    );
    expect(() => ActivityPalette.forSeed(-3, Brightness.dark), returnsNormally);
  });

  test('nextSeed gives the first twelve activities distinct hues', () {
    final used = <int>[];
    for (var i = 0; i < ActivityPalette.length; i++) {
      used.add(ActivityPalette.nextSeed(used));
    }
    expect(used.toSet(), hasLength(ActivityPalette.length));
  });

  test('nextSeed reuses the least-used slot once all are taken', () {
    final used = <int>[
      for (var i = 0; i < ActivityPalette.length; i++) i,
      0,
      1,
    ];
    expect(ActivityPalette.nextSeed(used), 2);
  });

  test('every edge colour reads as an edge against its own fill', () {
    for (var seed = 0; seed < ActivityPalette.length; seed++) {
      for (final brightness in Brightness.values) {
        final colors = ActivityPalette.forSeed(seed, brightness);
        final ratio = contrastRatio(colors.fill, colors.edge);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason:
              'the spine on a block must be visible against the block: seed '
              '$seed in $brightness is only ${ratio.toStringAsFixed(2)}:1',
        );
      }
    }
  });

  test('neighbouring slots differ in lightness, not only in hue', () {
    // Colour-blind and grayscale readers get nothing from the hue step, so two
    // activities created one after the other must differ in luminance too
    // (SPEC §10.3).
    for (final brightness in Brightness.values) {
      for (var seed = 0; seed < ActivityPalette.length - 1; seed++) {
        final a = ActivityPalette.forSeed(seed, brightness).fill;
        final b = ActivityPalette.forSeed(seed + 1, brightness).fill;
        expect(
          (relativeLuminance(a) - relativeLuminance(b)).abs(),
          greaterThan(0.01),
          reason: 'seeds $seed and ${seed + 1} in $brightness look alike',
        );
      }
    }
  });

  test('no activity hue strays into the arc reserved for the app', () {
    // SPEC §9.7: the live accent lives in this arc and means "now", so nothing
    // else may be that colour.
    for (var seed = 0; seed < ActivityPalette.length; seed++) {
      final hue = ActivityPalette.hues[seed];
      expect(
        hue >= ActivityPalette.reservedHueStart &&
            hue <= ActivityPalette.reservedHueEnd,
        isFalse,
        reason: 'seed $seed is at $hue, inside the reserved arc',
      );
    }
  });

  test('consecutive seeds are far apart in hue', () {
    // Activities take the least-used slot in order, so slots 0 and 1 are the
    // two colours a new user sees side by side.
    double separation(double a, double b) {
      final diff = (a - b).abs();
      return diff > 180 ? 360 - diff : diff;
    }

    for (var seed = 0; seed < ActivityPalette.length - 1; seed++) {
      expect(
        separation(ActivityPalette.hues[seed], ActivityPalette.hues[seed + 1]),
        greaterThanOrEqualTo(45),
        reason: 'seeds $seed and ${seed + 1} are neighbours on the wheel',
      );
    }
  });
}
