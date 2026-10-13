import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'design.dart';
import 'platform_style.dart';

/// Material 3, standard components, no custom chrome (SPEC §1 principle 4).
///
/// Everything visual is decided here: a widget that needs a colour, a radius or
/// a text style asks the theme for it rather than inventing one. The palette of
/// activity colours (`palette.dart`) is the single exception, because it is
/// keyed by activity rather than by role.
ThemeData buildAppTheme(Brightness brightness, [PlatformStyle? platform]) {
  final style = platform ?? PlatformStyle.forCurrent();
  final scheme = _scheme(brightness);
  final colors = AppColors.of(brightness, scheme);
  final text = _typography(
    brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black,
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: AppType.sans,
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[colors],
    visualDensity: style.density,
    // Explicit, so that transitions, scroll physics, text selection and the
    // back gesture all agree with the style the theme was built for.
    platform: platform == null ? null : _platformFor(style),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Flutter's defaults are already these; naming them is what keeps the
        // reasoning with the code. Cupertino's transition is also what gives
        // iOS and macOS their edge-swipe back.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    // SPEC §10.2: every interactive target is at least 48x48.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: scheme.surface,

    // ---------------------------------------------------------------- surfaces
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: style.containerBorderRadius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      // Transparent on glass platforms: the sheet paints its own material.
      backgroundColor: style.glass
          ? Colors.transparent
          : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      // Material's sheet announces itself with a handle; an Apple sheet is
      // inset and rounded and says the same thing with its shape.
      showDragHandle: style.sheetDragHandle,
      shape: RoundedRectangleBorder(borderRadius: style.sheetBorderRadius),
    ),
    dividerTheme: DividerThemeData(
      color: colors.hairline,
      thickness: Strokes.hairline,
      space: Strokes.hairline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: style.centredTitle,
      titleTextStyle: text.titleMedium,
    ),

    // ---------------------------------------------------------------- controls
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(text, style)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _buttonStyle(text, style),
    ),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle(text, style)),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: style.pillButtons
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: style.controlBorderRadius),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle: text.labelLarge,
        shape: style.pillButtons
            ? const StadiumBorder()
            : RoundedRectangleBorder(borderRadius: style.controlBorderRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      border: OutlineInputBorder(
        borderRadius: style.controlBorderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: style.controlBorderRadius,
        borderSide: BorderSide.none,
      ),
      // Focus is live: the field you are in is the thing you are acting on now.
      focusedBorder: OutlineInputBorder(
        borderRadius: style.controlBorderRadius,
        borderSide: BorderSide(color: colors.live, width: Strokes.focus),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: style.controlBorderRadius),
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: text.labelMedium,
      shape: const RoundedRectangleBorder(borderRadius: Radii.pill),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: style.controlBorderRadius,
      ),
      textStyle: text.labelSmall?.copyWith(color: scheme.onInverseSurface),
    ),
    scrollbarTheme: ScrollbarThemeData(
      // Thin and quiet: the day is a tall scroll, and a full-weight bar down
      // the side of it competes with the blocks.
      thickness: const WidgetStatePropertyAll<double>(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll<Color>(
        scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: style.controlBorderRadius),
      insetPadding: const EdgeInsets.all(Insets.md),
    ),
  );
}

/// Ink: what a primary action is drawn in.
///
/// Not a hue. Start, Stop and Save are the loudest controls on the screen and
/// they are deliberately colourless, because colour here has to be kept for the
/// things it means something about (SPEC §9.8). A black button on white is also
/// the plainest way to say "this is the one to press".
const Color _inkLight = Color(0xFF17171A);
const Color _inkDark = Color(0xFFF2F2F4);

/// The seed for the neutral ramp. Barely blue, so the greys are not dead.
const Color _seed = Color(0xFF3A6EA5);

/// **Live**: the one accent, and it means *now*.
///
/// The now-line, the running indicator and the focus ring — the present moment
/// and the thing you are acting on in it. Nothing else may use it, and the hue
/// arc it sits in is struck from the activity palette, so a vivid indigo on
/// screen never means "an activity someone named indigo" (SPEC §9.7).
///
/// Both tones clear 3:1 against their own surface (the now-line is a two-pixel
/// line, SPEC §10.3) and carry their label at 4.5:1. `test/app/theme_test.dart`
/// asserts it rather than trusting it.
const Color _liveLight = Color(0xFF6D4AFF);
const Color _liveDark = Color(0xFFB3A3FF);

/// Near-neutral surfaces, ink actions, one reserved accent.
///
/// `DynamicSchemeVariant.neutral` gives greys for every surface and outline,
/// which is what lets the twelve activity colours and the live accent be the
/// only colour on screen. `primary` is then overridden to ink, which carries
/// through every Material component that reaches for it — filled buttons, the
/// field's focus fill, the segmented button's selection, switches, the date
/// picker — in one move.
ColorScheme _scheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final neutral = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  return neutral.copyWith(
    primary: dark ? _inkDark : _inkLight,
    onPrimary: dark ? _inkLight : Colors.white,
  );
}

ButtonStyle _buttonStyle(TextTheme text, PlatformStyle style) => ButtonStyle(
  textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
  // The *visual* height. `materialTapTargetSize: padded` still guarantees the
  // 48 dp target around it, so a dense desktop button stays hittable
  // (SPEC §10.2).
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, style.buttonHeight)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: style.compact ? Insets.md : Insets.lg),
  ),
  shape: WidgetStatePropertyAll<OutlinedBorder>(style.buttonShape),
);

/// The target platform a hand-picked [PlatformStyle] implies, so that a theme
/// built for one idiom does not then get another's scroll physics.
TargetPlatform _platformFor(PlatformStyle style) => switch (style.idiom) {
  PlatformIdiom.apple => TargetPlatform.iOS,
  PlatformIdiom.material => TargetPlatform.android,
  PlatformIdiom.fluent => TargetPlatform.windows,
  PlatformIdiom.gnome => TargetPlatform.linux,
};

/// The sans, tuned.
///
/// No blanket tabular-figures setting any more: the numbers that used to need
/// it are now set in the mono, which is tabular by construction, and the sans
/// is left to do what it is for. Titles go to 600 and the large sizes lose a
/// little tracking, which is how a grotesque wants to be set.
TextTheme _typography(TextTheme rawBase) {
  // Applied here rather than through `ThemeData.fontFamily`: that only dresses
  // the *default* text theme, and this one is passed in explicitly, so it would
  // have stayed Roboto. `theme_test.dart` is what noticed.
  final base = rawBase.apply(fontFamily: AppType.sans);
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(letterSpacing: -1),
    headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.5),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// App roles the Material scheme has no word for.
///
/// Without these the now-line ends up drawn in `colorScheme.error`, which says
/// "something is wrong" about a line that only says "it is 15:04". Each role is
/// named for what it means, not for what colour it happens to be.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.live,
    required this.onLive,
    required this.axisRule,
    required this.axisRuleFaint,
    required this.gutterSpine,
    required this.hairline,
    required this.gapInk,
    required this.gapStroke,
    required this.scrim,
    required this.specular,
  });

  /// Derived from the scheme so light and dark stay in step automatically.
  factory AppColors.of(Brightness brightness, ColorScheme scheme) => AppColors(
    live: brightness == Brightness.dark ? _liveDark : _liveLight,
    onLive: brightness == Brightness.dark ? _inkLight : Colors.white,
    axisRule: scheme.outlineVariant,
    axisRuleFaint: scheme.outlineVariant.withValues(alpha: 0.45),
    gutterSpine: scheme.outlineVariant.withValues(alpha: 0.7),
    hairline: scheme.outlineVariant.withValues(alpha: 0.6),
    gapInk: scheme.onSurfaceVariant,
    gapStroke: scheme.outlineVariant.withValues(alpha: 0.8),
    scrim: scheme.scrim.withValues(alpha: 0.26),
    specular: brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.65),
  );

  /// *Now*: the now-line and its pill, the running indicator, the focus ring.
  /// The app's only accent, and the only thing allowed to use it (SPEC §9.8).
  final Color live;
  final Color onLive;

  /// Hour rules, half-hour hairlines, and the vertical line closing the gutter.
  final Color axisRule;
  final Color axisRuleFaint;
  final Color gutterSpine;

  /// Dividers between the three zones of the screen.
  final Color hairline;

  /// Untracked time: its label and its outline (SPEC §4.7).
  final Color gapInk;
  final Color gapStroke;

  /// Dims the day behind the suggestion panel.
  final Color scrim;

  /// The lit edge of a glass surface (SPEC §9.8). Decoration only: nothing is
  /// ever told apart by it.
  final Color specular;

  static AppColors from(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        AppColors.of(theme.brightness, theme.colorScheme);
  }

  @override
  AppColors copyWith({
    Color? live,
    Color? onLive,
    Color? axisRule,
    Color? axisRuleFaint,
    Color? gutterSpine,
    Color? hairline,
    Color? gapInk,
    Color? gapStroke,
    Color? scrim,
    Color? specular,
  }) => AppColors(
    live: live ?? this.live,
    onLive: onLive ?? this.onLive,
    axisRule: axisRule ?? this.axisRule,
    axisRuleFaint: axisRuleFaint ?? this.axisRuleFaint,
    gutterSpine: gutterSpine ?? this.gutterSpine,
    hairline: hairline ?? this.hairline,
    gapInk: gapInk ?? this.gapInk,
    gapStroke: gapStroke ?? this.gapStroke,
    scrim: scrim ?? this.scrim,
    specular: specular ?? this.specular,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      live: Color.lerp(live, other.live, t)!,
      onLive: Color.lerp(onLive, other.onLive, t)!,
      axisRule: Color.lerp(axisRule, other.axisRule, t)!,
      axisRuleFaint: Color.lerp(axisRuleFaint, other.axisRuleFaint, t)!,
      gutterSpine: Color.lerp(gutterSpine, other.gutterSpine, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      gapInk: Color.lerp(gapInk, other.gapInk, t)!,
      gapStroke: Color.lerp(gapStroke, other.gapStroke, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      specular: Color.lerp(specular, other.specular, t)!,
    );
  }
}
