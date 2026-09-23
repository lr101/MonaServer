import 'dart:io';

import 'package:buff_lisa/app/app.dart';
import 'package:buff_lisa/app/app_configuration.dart';
import 'package:buff_lisa/app/email_link_launch.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/email_login/data/email_login_providers.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/firebase_options.dart';
import 'package:buff_lisa/util/core/cache_migrator.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads bundled values; build-time overrides are validated by bootstrap.
Future<Map<String, String>> loadAppEnvironment() async {
  const isProduction = bool.fromEnvironment('dart.vm.product');
  await dotenv.load(fileName: isProduction ? 'config' : 'config.dev');
  return Map<String, String>.of(dotenv.env);
}

Future<EmailLinkLaunchData?> captureProductionEmailLinkLaunch() =>
    captureInitialEmailLink();

/// Owns platform initialization and the legacy provider composition root.
Future<Widget> initializeApplication(
  AppConfiguration configuration, {
  EmailLinkLaunchData? launchData,
}) async {
  // Legacy consumers still read dotenv until their feature migration.
  dotenv.env['API_HOST'] = configuration.apiHost;
  final sharedPreferences = await SharedPreferences.getInstance();
  final cacheMigrator = CacheMigrator(
    prefs: sharedPreferences,
    latestVersion: 2,
  );
  await cacheMigrator.noDatabaseMigrate();

  // Account facades share the bootstrap executor and its migration owner.
  // Their overlap during provider disposal is intentional.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Initialize Drift database (cross-platform)
  final database = AppDatabase();

  try {
    await cacheMigrator.migrate();

    try {
      if (!kIsWeb) {
        await FMTCObjectBoxBackend().initialise();
        final mgmt = const FMTCStore('tileStore').manage;
        final ready = await mgmt.ready; // Check whether the store exists
        if (!ready) await mgmt.create(maxLength: 2000); // Create the store
      }
    } catch (e) {
      if (!kIsWeb) {
        final dir = Directory(
          path.join(
            (await getApplicationDocumentsDirectory()).absolute.path,
            'fmtc',
          ),
        );
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        await FMTCObjectBoxBackend().initialise();
      }
    }
    ISecureStorage storage;
    if (kIsWeb) {
      storage = WebSecureStorage();
    } else {
      storage = MobileSecureStorage();
    }

    final globalData = await GlobalDataRepository.get(
      sharedPreferences,
      storage,
    );
    final globalUserData = await GlobalDataRepository.getUser(
      sharedPreferences,
      storage,
    );
    final defaultGroupImage = (await rootBundle.load(
      'assets/image/pin_border.png',
    )).buffer.asUint8List();
    final defaultErrorImage = (await rootBundle.load(
      'assets/image/profile_blank.jpg',
    )).buffer.asUint8List();

    if (!kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    }

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(storage),
        globalDataOnceProvider.overrideWithValue(globalData),
        currentUserOnceProvider.overrideWithValue(globalUserData),
        defaultGroupPinImageProvider.overrideWithValue(defaultGroupImage),
        defaultErrorImageProvider.overrideWithValue(defaultErrorImage),
        driftRepoProvider.overrideWithValue(database),
        emailLinkLaunchDataProvider.overrideWithValue(launchData),
      ],
      child: const MyApp(),
    );
  } catch (_) {
    await database.close();
    rethrow;
  }
}
