import 'package:buff_lisa/app/app_configuration.dart';
import 'package:flutter/material.dart';

/// Gates all platform/storage work on valid configuration and completed restore.
/// Dependencies are supplied by the composition root, so startup can be tested
/// without invoking plugins or contacting the configured backend.
Future<Widget> bootstrapApplication<T>({
  required Future<Map<String, String>> Function() loadConfiguration,
  required Future<Widget> Function(AppConfiguration) initialize,
  Future<Widget> Function(AppConfiguration, T?)? initializeWithLaunchData,
  Future<T?> Function()? captureLaunchData,
  String apiHostOverride = '',
}) async {
  T? launchData;
  try {
    if (captureLaunchData != null) launchData = await captureLaunchData();
  } catch (_) {
    // Capture failure must not prevent the existing password-login startup.
  }
  try {
    final configuration = AppConfiguration.fromEnvironment(
      await loadConfiguration(),
      apiHostOverride: apiHostOverride,
    );
    if (initializeWithLaunchData != null) {
      return await initializeWithLaunchData(configuration, launchData);
    }
    return await initialize(configuration);
  } catch (_) {
    // Exception messages from storage/plugins may include credentials or data.
    return const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unable to start Stick-It'),
                  SizedBox(height: 12),
                  Text(
                    'Please close and reopen the app. If this continues, contact support.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
