import 'package:buff_lisa/data/config/posthog_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not configure PostHog without an API key', () {
    expect(PosthogSettings.fromEnvironment({}), isNull);
  });

  test('loads PostHog settings from the build environment', () {
    final settings = PosthogSettings.fromEnvironment({
      'POSTHOG_API_KEY': 'test-api-key',
      'POSTHOG_HOST': 'https://posthog.example.test',
    }, isProduction: true);

    expect(settings, isNotNull);
    expect(settings!.apiKey, 'test-api-key');
    expect(settings.host, 'https://posthog.example.test');
    expect(settings.captureApplicationLifecycleEvents, isTrue);
    expect(settings.debug, isFalse);
  });
}
