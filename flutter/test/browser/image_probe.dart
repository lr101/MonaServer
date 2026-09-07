import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

@JS('document.body.setAttribute')
external void setProbeAttribute(String name, String value);

// Browser-only entry point: real HTTP, browser database, and image decoding.
// The runner provides loopback API/storage fixtures and blocks external traffic.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var database = AppDatabase();
  final client = ApiClient(basePath: Uri.base.origin);
  final groups = GroupsApi(client);
  final users = UsersApi(client);
  final pins = PinsApi(client);
  final endpoints = <ImageType, Future<String?> Function(String)>{
    ImageType.pin: pins.getPinImage,
    ImageType.user: users.getUserProfileImage,
    ImageType.userSmall: users.getUserProfileImageSmall,
    ImageType.group: groups.getGroupProfileImage,
    ImageType.groupSmall: groups.getGroupProfileImageSmall,
    ImageType.groupPin: groups.getGroupPinImage,
  };
  final mode = Uri.base.queryParameters['mode'] ?? 'fresh';
  var result = 'passed';
  try {
    if (mode == 'migration') {
      await database.customSelect('SELECT 1').get();
      await database.customStatement('DROP TABLE image_entities');
      await database.customStatement('''
        CREATE TABLE image_entities (
          isar_id INTEGER NOT NULL PRIMARY KEY,
          ttl INTEGER NOT NULL,
          hits INTEGER NOT NULL DEFAULT 1,
          keep_alive INTEGER NOT NULL DEFAULT 0,
          only_session INTEGER NOT NULL DEFAULT 0,
          id TEXT NOT NULL,
          type INTEGER NOT NULL,
          image BLOB
        )
      ''');
      final seed = await http.get(Uri.base.resolve('/seed.png'));
      for (final type in ImageType.values) {
        await database.customStatement(
          'INSERT INTO image_entities (isar_id, ttl, id, type, image) VALUES (?, ?, ?, ?, ?)',
          [
            type.index + 1,
            DateTime.now()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch ~/
                1000,
            'local-image',
            type.index,
            seed.bodyBytes,
          ],
        );
      }
      await database.customStatement('PRAGMA user_version = 1');
      await database.close();
      database = AppDatabase();
    }
    for (final entry in endpoints.entries) {
      final repo = ImageRepository(
        db: database,
        type: entry.key,
        getImageUrl: entry.value,
      );
      await repo.ready;
      if (mode == 'retained-empty') {
        await repo.doPut(
          ImageEntity(
            id: 'local-image',
            type: entry.key,
            image: Uint8List(0),
            keepAlive: true,
            ttl: DateTime.now().subtract(const Duration(minutes: 1)),
            onlySession: false,
          ),
        );
      }
      final watched = Completer<Uint8List>();
      final subscription = repo.watchImageBytes('local-image').listen((bytes) {
        if (bytes != null && bytes.isNotEmpty && !watched.isCompleted) {
          watched.complete(bytes);
        }
      });
      try {
        final fetched = await repo
            .fetchImage('local-image', false)
            .timeout(const Duration(seconds: 20));
        if (fetched == null || fetched.isEmpty) {
          throw StateError('${entry.key.name}: image fetch returned no bytes');
        }
        final bytes = await watched.future.timeout(const Duration(seconds: 10));
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (frame.image.width != 1 || frame.image.height != 1) {
          throw StateError('${entry.key.name}: unexpected image dimensions');
        }
        frame.image.dispose();
        codec.dispose();
        debugPrint('IMAGE PROBE: ${entry.key.name} passed');
      } finally {
        await subscription.cancel();
        // Drain pruning scheduled by watcher cancellation before closing the DB.
        await repo.deleteOldestItems();
      }
    }
  } catch (e, stack) {
    debugPrint('IMAGE PROBE FAILED: $e\n$stack');
    result = 'failed: $e';
  } finally {
    client.client.close();
    await database.close();
  }
  setProbeAttribute('data-image-probe', result);
}
