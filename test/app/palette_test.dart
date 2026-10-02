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
}
