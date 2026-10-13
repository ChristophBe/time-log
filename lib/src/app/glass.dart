import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'platform_style.dart';
import 'theme.dart';

/// Apple's Liquid Glass, as far as Flutter can honestly draw it.
///
/// Three things make the material read: it is translucent, it blurs what is
/// behind it, and it carries a bright specular edge where the light catches its
/// top. Flutter gives us the first two directly; the third is a gradient
/// hairline. What it cannot do is refract, so this is a likeness rather than a
/// reproduction -- which is why it is only used where there is genuinely
/// something behind it to see (SPEC §9.8).
///
/// **It degrades to opaque.** Apple's own material does the same under Reduce
/// Transparency. Flutter does not surface that setting, so the nearest honest
/// signal is `MediaQuery.highContrast` (iOS's Increase Contrast), and a blur is
/// also simply skipped on platforms that are not Apple. Text contrast is
/// measured against the opaque tint either way, so SPEC §10.3 holds in both
/// states.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.edge = GlassEdge.top,
    this.opacity = 0.72,
    this.blur = 24,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Which side the specular hairline is drawn on.
  final GlassEdge edge;

  /// How solid the tint is. Lower is more glass; below about 0.6 the text on it
  /// starts to fight whatever is behind.
  final double opacity;

  final double blur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid =
        !PlatformStyle.from(context).glass ||
        MediaQuery.highContrastOf(context);
    final tint = solid
        ? scheme.surface
        : scheme.surface.withValues(alpha: opacity);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        border: solid ? null : _specular(context),
      ),
      child: child,
    );

    if (solid) {
      return borderRadius == BorderRadius.zero
          ? body
          : ClipRRect(borderRadius: borderRadius, child: body);
    }
    // The shadow sits outside the clip, or it would be clipped away with
    // everything else. Glass floats, and a floating thing that casts nothing
    // reads as a flat panel the same colour as its background — which in light
    // mode is most of what separates this header from the day under it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: Offset(0, switch (edge) {
              GlassEdge.bottom => 4,
              GlassEdge.top => -4,
              _ => 0,
            }),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: body,
        ),
      ),
    );
  }

  /// The highlight along the lit edge. One hairline, not a full outline: a box
  /// drawn all the way round reads as a border, which is the thing Liquid Glass
  /// does away with.
  Border _specular(BuildContext context) {
    final line = BorderSide(
      color: AppColors.from(context).specular,
      width: 0.5,
    );
    return switch (edge) {
      GlassEdge.top => Border(top: line),
      GlassEdge.bottom => Border(bottom: line),
      GlassEdge.all => Border.fromBorderSide(line),
      GlassEdge.none => const Border(),
    };
  }
}

enum GlassEdge { top, bottom, all, none }
