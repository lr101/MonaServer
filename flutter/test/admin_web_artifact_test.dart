import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin web template has an independent local-only shell', () {
    final index = File('web_admin/index.html').readAsStringSync();

    expect(index, contains('data-admin-entry="true"'));
    expect(index, contains('Stick-It Admin'));
    expect(
      index,
      contains(
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';",
      ),
    );
    expect(
      index,
      contains("connect-src 'self' https://stick-it.lr-projects.de"),
    );
    expect(
      index,
      contains("object-src 'none'; base-uri 'self'; frame-ancestors 'none'"),
    );
    expect(index, contains("script-src 'self'"));
    expect(
      RegExp(
        r"script-src\s+[^;]*\s+(?!'self'(?:\s*;|\s*$))",
        caseSensitive: false,
      ).hasMatch(index),
      isFalse,
    );
    expect(index, contains('admin-logo.svg'));
    expect(index, contains('admin_splash.js'));
    expect(
      index,
      isNot(contains('assets/assets/icon/logo-rounded-corners.png')),
    );
    expect(index, isNot(contains('cdnjs.cloudflare.com')));
    expect(index, isNot(contains('cropper')));
    expect(
      RegExp(
        r'''<script[^>]+src=["'](?:https?:|//)''',
        caseSensitive: false,
      ).hasMatch(index),
      isFalse,
    );
    expect(
      RegExp(
        r'<script(?![^>]+\bsrc=)[^>]*>',
        caseSensitive: false,
      ).hasMatch(index),
      isFalse,
    );
  });
}
