import 'dart:async';

import 'package:buff_lisa/app/app_configuration.dart';
import 'package:buff_lisa/app/bootstrap.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the build override and normalizes the API origin', () {
    final config = AppConfiguration.fromEnvironment({
      'API_HOST': 'https://unused.example',
    }, apiHostOverride: ' http://127.0.0.1:8081/// ');
    expect(config.apiHost, 'http://127.0.0.1:8081');
  });

  test('accepts the configured backend when no override is supplied', () {
    expect(
      AppConfiguration.fromEnvironment({'API_HOST': 'https://api.example/'})
          .apiHost,
      'https://api.example',
    );
  });

  for (final host in [
    null,
    '',
    ' ',
    'api.example',
    'ftp://api.example',
    'https://user:secret@api.example',
    'https://api.example/path',
    'https://api.example?token=secret',
    'https://api.example#secret',
    'https://',
    'https://@api.example',
    'https://bad host',
    'https://%',
    'https://bad%20host',
    'https://api.example:abc',
    'http://localhost:0',
    'http://localhost:65536',
  ]) {
    test('rejects invalid API origin ${host ?? "missing"}', () {
      expect(
        () => AppConfiguration.fromEnvironment({
          if (host != null) 'API_HOST': host,
        }),
        throwsA(isA<AppConfigurationException>()),
      );
    });
  }

  testWidgets(
    'invalid configuration stops initialization and renders safe error',
    (tester) async {
      var initialized = false;
      final app = await bootstrapApplication(
        loadConfiguration: () async => {
          'API_HOST': 'https://user:secret@api.example',
        },
        initialize: (_) async {
          initialized = true;
          return const Text('ready');
        },
      );
      await tester.pumpWidget(app);
      expect(initialized, isFalse);
      expect(find.text('Unable to start Stick-It'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    },
  );

  testWidgets(
    'initialization failure renders an error without exposing details',
    (tester) async {
      final app = await bootstrapApplication(
        loadConfiguration: () async => {'API_HOST': 'https://api.example'},
        initialize: (_) async => throw StateError('secret refresh credential'),
      );
      await tester.pumpWidget(app);
      expect(find.text('Unable to start Stick-It'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    },
  );

  testWidgets('configuration load failure renders a safe error', (
    tester,
  ) async {
    final app = await bootstrapApplication(
      loadConfiguration: () async => throw StateError('secret asset content'),
      initialize: (_) async => const Text('ready'),
    );
    await tester.pumpWidget(app);
    expect(find.text('Unable to start Stick-It'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets(
    'startup waits for restored dependencies before returning the app',
    (tester) async {
      final restored = Completer<Widget>();
      var finished = false;
      String? host;
      final pending =
          bootstrapApplication(
            loadConfiguration: () async => {'API_HOST': 'https://api.example/'},
            initialize: (config) {
              host = config.apiHost;
              return restored.future;
            },
          ).then((app) {
            finished = true;
            return app;
          });
      await tester.pump();
      expect(finished, isFalse);
      expect(host, 'https://api.example');
      restored.complete(const MaterialApp(home: Text('restored app')));
      await tester.pumpWidget(await pending);
      expect(find.text('restored app'), findsOneWidget);
    },
  );

  testWidgets('passes captured email launch data to the composition root', (
    tester,
  ) async {
    final launch = EmailLinkLaunchData.captured(
      EmailLinkToken.tryParse('opaque-token')!,
    );
    EmailLinkLaunchData? received;
    final app = await bootstrapApplication(
      loadConfiguration: () async => {'API_HOST': 'https://api.example'},
      captureLaunchData: () async => launch,
      initializeWithLaunchData: (config, launchData) async {
        received = launchData;
        return const MaterialApp(home: Text('launch ready'));
      },
      initialize: (_) async => const MaterialApp(home: Text('wrong path')),
    );

    await tester.pumpWidget(app);

    expect(received, launch);
    expect(find.text('launch ready'), findsOneWidget);
  });
}
