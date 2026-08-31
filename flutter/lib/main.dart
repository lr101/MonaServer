import 'dart:async';
import 'dart:io';

import 'package:buff_lisa/data/config/posthog_settings.dart';
import 'package:buff_lisa/data/config/posthog_web_stub.dart'
    if (dart.library.js_interop) 'package:buff_lisa/data/config/posthog_web.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/firebase_options.dart';
import 'package:buff_lisa/util/core/cache_migrator.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:buff_lisa/util/theme/service/theme_state.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
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
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// THIS IS THE START OF THE PROGRAMM
/// binding Widgets before initialization is required by multiple packages
/// initializes access to env variables
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final cacheMigrator = CacheMigrator(
    prefs: sharedPreferences,
    latestVersion: 2,
  );
  await cacheMigrator.noDatabaseMigrate();

  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  if (isProduction) {
    await dotenv.load(fileName: "config");
  } else {
    await dotenv.load(fileName: "config.dev");
  }

  final posthogSettings = PosthogSettings.fromEnvironment(
    dotenv.env,
    isProduction: isProduction,
  );
  if (posthogSettings != null) {
    await initializePosthogWeb(
      apiKey: posthogSettings.apiKey,
      host: posthogSettings.host,
      debug: posthogSettings.debug,
    );
    final posthogConfig = PostHogConfig(posthogSettings.apiKey)
      ..host = posthogSettings.host
      ..captureApplicationLifecycleEvents =
          posthogSettings.captureApplicationLifecycleEvents
      ..debug = posthogSettings.debug;
    await Posthog().setup(posthogConfig);
  } else if (isProduction) {
    debugPrint(
      'PostHog is disabled because POSTHOG_API_KEY is not configured.',
    );
  }

  // Initialize Drift database (cross-platform)
  final database = AppDatabase();

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

  final globalData = await GlobalDataRepository.get(sharedPreferences, storage);
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

  Posthog().screen(screenName: "main");

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(storage),
        globalDataOnceProvider.overrideWithValue(globalData),
        currentUserOnceProvider.overrideWithValue(globalUserData),
        defaultGroupPinImageProvider.overrideWithValue(defaultGroupImage),
        defaultErrorImageProvider.overrideWithValue(defaultErrorImage),
        driftRepoProvider.overrideWithValue(database),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    final theme = MaterialTheme(Theme.of(context).textTheme);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Mona App',
      themeMode: ref.watch(themeStateProvider),
      darkTheme: theme.dark(),
      theme: theme.light(),
      routerConfig: router,
      builder: (context, child) {
        if (!kIsWeb) return child!;
        return ColoredBox(
          color: Colors.black, // Background color for web outside the app
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
