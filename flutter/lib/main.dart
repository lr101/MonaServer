import 'package:buff_lisa/app/bootstrap.dart';
import 'package:buff_lisa/app/production_bootstrap.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    await bootstrapApplication(
      loadConfiguration: loadAppEnvironment,
      initialize: initializeApplication,
      captureLaunchData: captureProductionEmailLinkLaunch,
      initializeWithLaunchData: (configuration, launchData) =>
          initializeApplication(configuration, launchData: launchData),
      // The release/local build can supply this value with --dart-define.
      // ignore: avoid_redundant_argument_values
      apiHostOverride: const String.fromEnvironment('API_HOST'),
    ),
  );
}
