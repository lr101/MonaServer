import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_offline_web.dart';

void main() {
  test('offline worker caches release assets and versions their contents', () async {
    final build = await Directory.systemTemp.createTemp('offline-web-build-');
    addTearDown(() => build.delete(recursive: true));

    Future<void> put(String path, String contents) async {
      final file = File('${build.path}/$path');
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
    }

    await put('index.html', '<html></html>');
    await put('flutter_bootstrap.js', 'bootstrap');
    await put('main.dart.js', 'javascript build');
    await put('main.dart.mjs', 'wasm bootstrap');
    await put('main.dart.wasm', 'wasm build');
    await put('sqlite3.wasm', 'database');
    await put('drift_worker.js', 'worker');
    await put('assets/config', 'API_HOST=example');
    await put('assets/images/logo.png', 'image');
    await put('main.dart.js.map', 'debug map');

    await generateOfflineWeb(build);
    final first = await File('${build.path}/offline-sw.js').readAsString();
    for (final path in [
      '/index.html',
      '/flutter_bootstrap.js',
      '/main.dart.js',
      '/main.dart.mjs',
      '/main.dart.wasm',
      '/sqlite3.wasm',
      '/drift_worker.js',
      '/assets/config',
      '/assets/images/logo.png',
    ]) {
      expect(first, contains('"$path"'));
    }
    expect(first, isNot(contains('main.dart.js.map')));

    await put('main.dart.js', 'changed javascript build');
    await generateOfflineWeb(build);
    final second = await File('${build.path}/offline-sw.js').readAsString();
    expect(second, isNot(first));
    expect(second, contains('"/main.dart.js"'));
  });
}
