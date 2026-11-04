import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  for (final scheme in [
    MaterialTheme.lightScheme(),
    MaterialTheme.darkScheme(),
  ]) {
    test('theme text and input outline contrast in ${scheme.brightness}', () {
      expect(
        contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.primaryOnSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.outline, scheme.surface), greaterThanOrEqualTo(3));
      for (final background in [
        scheme.surfaceContainer,
        scheme.surfaceContainerHighest,
      ]) {
        expect(
          contrast(scheme.onSurface, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      expect(
        contrast(scheme.onErrorContainer, scheme.errorContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
