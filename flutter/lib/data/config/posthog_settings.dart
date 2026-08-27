class PosthogSettings {
  const PosthogSettings({
    required this.apiKey,
    required this.host,
    required this.captureApplicationLifecycleEvents,
    required this.debug,
  });

  final String apiKey;
  final String host;
  final bool captureApplicationLifecycleEvents;
  final bool debug;

  static PosthogSettings? fromEnvironment(
    Map<String, String> environment, {
    bool isProduction = false,
  }) {
    final apiKey = environment['POSTHOG_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) return null;

    final configuredHost = environment['POSTHOG_HOST']?.trim();
    return PosthogSettings(
      apiKey: apiKey,
      host: configuredHost == null || configuredHost.isEmpty
          ? 'https://eu.i.posthog.com'
          : configuredHost,
      captureApplicationLifecycleEvents: true,
      debug: !isProduction,
    );
  }
}
