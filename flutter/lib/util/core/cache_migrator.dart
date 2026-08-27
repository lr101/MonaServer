import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheMigrator {

  final SharedPreferences prefs;
  late final int version;
  final int latestVersion;

  CacheMigrator({required this.prefs, required this.latestVersion}) {
    version = prefs.getInt("hiveVersion") ?? 0;
  }

  Future<void> noDatabaseMigrate() async {
    for (int v = version + 1; v <= latestVersion; v++) {
      switch (v) {
        case 2: await _version2();
      }
      await prefs.setInt("hiveVersion", v);
    }
  }

  Future<void> migrate() async {
    for (int v = version + 1; v <= latestVersion; v++) {
      switch (v) {
        case 1: await _version1();
      }
      await prefs.setInt("hiveVersion", v);
    }
  }

  Future<void> _version1() async {
    debugPrint("This was previously a Hive migrator that is not needed anymore");
  }

  Future<void> _version2() async {
    // 1. Clear ALL standard SharedPreferences.
    // Note: This does NOT affect flutter_secure_storage.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!kIsWeb) {
      final docDir = await getApplicationDocumentsDirectory();
      final docPath = docDir.path;

      // 2. Delete specific custom directories
      final directoriesToDelete = ['groups', 'pins', 'users'];
      for (final dirName in directoriesToDelete) {
        final dir = Directory('$docPath/$dirName');
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      }

      // 3. Delete Hive and Isar database files explicitly
      // Ideally, ensure your Isar and Hive instances are closed before doing this 
      // to prevent memory leaks or crashes (e.g., await Hive.close();)
      for (final entity in docDir.listSync()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          
          // Target specifically the extensions used by Hive and Isar
          if (fileName.endsWith('.hive') || 
              fileName.endsWith('.lock') || 
              fileName.endsWith('.isar')) {
            await entity.delete();
          }
        }
      }
    }
  }

}
