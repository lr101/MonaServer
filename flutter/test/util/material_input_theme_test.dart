import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('resting input has a visible outline in $brightness', (
      tester,
    ) async {
      final theme = MaterialTheme(ThemeData().textTheme);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light ? theme.light() : theme.dark(),
          home: const Scaffold(
            body: TextField(decoration: InputDecoration(labelText: 'Name')),
          ),
        ),
      );
      final effectiveTheme = Theme.of(tester.element(find.byType(TextField)));
      final border =
          effectiveTheme.inputDecorationTheme.enabledBorder!
              as OutlineInputBorder;
      expect(border.borderSide.style, BorderStyle.solid);
      expect(
        border.borderSide.color,
        theme
            .theme(
              brightness == Brightness.light
                  ? MaterialTheme.lightScheme()
                  : MaterialTheme.darkScheme(),
            )
            .colorScheme
            .outline,
      );
    });
  }
}
