import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/app/design.dart';
import 'package:time_log/src/app/palette.dart';
import 'package:time_log/src/app/theme.dart';
import 'package:time_log/src/core/color_contrast.dart';

/// The identity rules of SPEC §9.8, asserted rather than trusted.
void main() {
  ThemeData theme(Brightness b) => buildAppTheme(b);
  AppColors colorsFor(Brightness b) =>
      theme(b).extension<AppColors>() ?? AppColors.of(b, theme(b).colorScheme);

  group('the live accent', () {
    test('is legible as a two-pixel line on its own surface', () {
      for (final brightness in Brightness.values) {
        final scheme = theme(brightness).colorScheme;
        final ratio = contrastRatio(colorsFor(brightness).live, scheme.surface);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason:
              'the now-line is 2px and must clear 3:1 (SPEC §10.3): '
              '$brightness is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('carries its pill label', () {
      for (final brightness in Brightness.values) {
        final colors = colorsFor(brightness);
        final ratio = contrastRatio(colors.live, colors.onLive);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              'the now pill prints a time on the accent (SPEC §10.3): '
              '$brightness is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('is not a colour any activity can wear', () {
      // The point of the reserved arc (SPEC §9.7): a vivid indigo on screen
      // means "now", never "the activity someone named indigo".
      for (final brightness in Brightness.values) {
        final live = HSLColor.fromColor(colorsFor(brightness).live).hue;
        expect(
          live,
          inInclusiveRange(
            ActivityPalette.reservedHueStart,
            ActivityPalette.reservedHueEnd,
          ),
          reason: 'the accent must sit inside the arc the palette avoids',
        );
      }
    });
  });

  group('chrome', () {
    test('primary is ink, not a hue', () {
      // SPEC §9.8: Start, Stop and Save are colourless, which is what keeps the
      // accent rare enough to mean something.
      for (final brightness in Brightness.values) {
        final primary = theme(brightness).colorScheme.primary;
        final saturation = HSLColor.fromColor(primary).saturation;
        expect(
          saturation,
          lessThan(0.1),
          reason: '$brightness primary is ${primary.toString()}',
        );
      }
    });

    test('a filled button prints its label legibly', () {
      for (final brightness in Brightness.values) {
        final scheme = theme(brightness).colorScheme;
        expect(
          contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  test('both voices are the vendored families', () {
    // If the fonts ever fall out of pubspec.yaml this is what notices.
    expect(theme(Brightness.light).textTheme.bodyMedium?.fontFamily, 'Geist');
    expect(
      AppType.numeric(theme(Brightness.light).textTheme.bodyMedium)?.fontFamily,
      'GeistMono',
    );
  });
}
