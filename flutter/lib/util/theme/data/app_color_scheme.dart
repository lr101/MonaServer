import 'package:flutter/material.dart';

extension AppColorScheme on ColorScheme {
  /// A readable brand accent for content drawn directly on a surface.
  ///
  /// The peach primary remains the fill color for actions, but does not have
  /// enough contrast against the light surface for small text or icons.
  Color get primaryOnSurface =>
      brightness == Brightness.light ? const Color(0xFF8A4B00) : primary;
}
