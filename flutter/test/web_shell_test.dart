import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web shell declares a safe viewport and a non-orange fallback', () {
    final html = File('web/index.html').readAsStringSync();
    final manifest = File('web/manifest.json').readAsStringSync();

    expect(
      html,
      contains(
        '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">',
      ),
    );
    expect(html, contains('background-color: #000000;'));
    expect(manifest, contains('"theme_color": "#000000"'));
  });
}
