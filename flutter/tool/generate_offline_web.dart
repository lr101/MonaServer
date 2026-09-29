import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Writes a service worker for the exact Flutter release bundle in [build].
Future<void> generateOfflineWeb(
  Directory build, {
  File? workerTemplate,
}) async {
  final root = build.absolute.path;
  final files = await build
      .list(recursive: true, followLinks: false)
      .where((entry) => entry is File)
      .cast<File>()
      .toList();

  final assets = <String, String>{};
  for (final file in files) {
    final relative = file.absolute.path.substring(root.length + 1).replaceAll(
      Platform.pathSeparator,
      '/',
    );
    if (relative == 'offline-sw.js' ||
        relative == 'flutter_service_worker.js' ||
        relative.endsWith('.map') ||
        relative.endsWith('.symbols')) {
      continue;
    }
    assets['/$relative'] = sha256.convert(await file.readAsBytes()).toString();
  }

  const required = [
    '/index.html',
    '/flutter_bootstrap.js',
    '/main.dart.js',
    '/main.dart.mjs',
    '/main.dart.wasm',
    '/sqlite3.wasm',
    '/drift_worker.js',
    '/assets/config',
  ];
  for (final path in required) {
    if (!assets.containsKey(path)) {
      throw StateError('Missing required offline web asset: $path');
    }
  }

  final paths = assets.keys.toList()..sort();
  final contents = paths.map((path) => '$path:${assets[path]}').join('\n');
  final version = sha256.convert(utf8.encode(contents)).toString();
  final template = await (workerTemplate ?? File('tool/offline-sw.template.js'))
      .readAsString();
  final worker = template
      .replaceAll('__OFFLINE_CACHE_NAME__', 'stickit-app-$version')
      .replaceAll('__OFFLINE_ASSETS__', jsonEncode(paths));
  await File('${build.path}/offline-sw.js').writeAsString(worker);
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/generate_offline_web.dart <build/web>');
    exitCode = 64;
    return;
  }
  await generateOfflineWeb(Directory(args.single));
}
