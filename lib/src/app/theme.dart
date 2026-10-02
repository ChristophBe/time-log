import 'package:flutter/material.dart';

/// Material 3, standard components, no custom chrome (SPEC §1 principle 4).
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3A6EA5),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    // SPEC §10.2: every interactive target is at least 48x48.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
