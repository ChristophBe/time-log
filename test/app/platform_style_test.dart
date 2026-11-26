import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_log/src/app/platform_style.dart';
import 'package:time_log/src/app/theme.dart';
import 'package:time_log/src/core/color_contrast.dart';

/// SPEC §9.8: the styling adapts, the identity does not.
void main() {
  const styles = <TargetPlatform, PlatformIdiom>{
    TargetPlatform.macOS: PlatformIdiom.apple,
    TargetPlatform.windows: PlatformIdiom.fluent,
    TargetPlatform.linux: PlatformIdiom.gnome,
  };

  test('every platform maps to the design system it belongs to', () {
    styles.forEach((platform, idiom) {
      expect(PlatformStyle.of(platform).idiom, idiom, reason: '$platform');
    });
  });

  test('the capsule platforms want a stadium, the cornered ones do not', () {
    // Liquid Glass wants a capsule; Fluent and GNOME both want corners.
    expect(PlatformStyle.apple.buttonShape, isA<StadiumBorder>());
    for (final style in <PlatformStyle>[
      PlatformStyle.fluent,
      PlatformStyle.gnome,
    ]) {
      expect(style.buttonShape, isA<RoundedRectangleBorder>());
    }
  });

  test('only Apple is made of glass', () {
    expect(PlatformStyle.apple.glass, isTrue);
    for (final style in <PlatformStyle>[
      PlatformStyle.fluent,
      PlatformStyle.gnome,
    ]) {
      expect(style.glass, isFalse);
    }
  });

  test('the desktop idioms are dense', () {
    expect(
      PlatformStyle.apple.compact,
      isFalse,
      reason: 'forCurrent tightens it',
    );
    expect(PlatformStyle.forCurrent, returnsNormally);
    expect(PlatformStyle.fluent.compact, isTrue);
    expect(PlatformStyle.gnome.compact, isTrue);
  });

  group('what a design system may not change', () {
    for (final entry in styles.entries) {
      final platform = entry.key;
      final style = PlatformStyle.of(platform);

      test('$platform keeps the colour contract', () {
        // SPEC §9.8 rule 2: the meanings are the app's, not the platform's.
        for (final brightness in Brightness.values) {
          final theme = buildAppTheme(brightness, style);
          final colors = theme.extension<AppColors>()!;
          expect(
            contrastRatio(colors.live, theme.colorScheme.surface),
            greaterThanOrEqualTo(3),
            reason: 'the now-line is 2px everywhere (SPEC §10.3)',
          );
          expect(
            contrastRatio(colors.live, colors.onLive),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            HSLColor.fromColor(theme.colorScheme.primary).saturation,
            lessThan(0.1),
            reason: 'primary is ink on every platform',
          );
        }
      });

      test('$platform keeps the two voices', () {
        final theme = buildAppTheme(Brightness.light, style);
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Geist');
      });

      test('$platform leaves room for a 48dp target', () {
        // A denser design system may draw a shorter button, but the tap target
        // around it is not negotiable (SPEC §10.2), which is what
        // materialTapTargetSize.padded guarantees.
        expect(style.buttonHeight, greaterThan(0));
        expect(
          buildAppTheme(Brightness.light, style).materialTapTargetSize,
          MaterialTapTargetSize.padded,
        );
      });
    }
  });
}
