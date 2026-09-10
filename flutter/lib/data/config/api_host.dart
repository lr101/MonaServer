const defaultApiHost = 'https://stick-it.lr-projects.de';

/// Resolves the API origin from the application configuration.
///
/// Web and native clients use the same configured backend origin. Keeping the
/// host independent from the page origin lets the web app call the API and
/// object storage directly.
String resolveApiHost({
  required String? configuredHost,
  String fallbackHost = defaultApiHost,
}) {
  final host = configuredHost?.trim();
  if (host == null || host.isEmpty) return fallbackHost;
  return host.replaceFirst(RegExp(r'/+$'), '');
}
