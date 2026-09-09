const defaultApiHost = 'https://stick-it.lr-projects.de';

/// Resolves the API origin for the current platform.
///
/// Flutter Web is served alongside the API proxy, so it must address the
/// current page origin. Native clients continue to use their configured
/// backend host.
String resolveApiHost({
  required bool isWeb,
  required Uri currentUri,
  required String? configuredHost,
  String fallbackHost = defaultApiHost,
}) {
  if (isWeb &&
      (currentUri.scheme == 'http' || currentUri.scheme == 'https') &&
      currentUri.host.isNotEmpty) {
    return currentUri.origin;
  }

  final host = configuredHost?.trim();
  if (host == null || host.isEmpty) return fallbackHost;
  return host.replaceFirst(RegExp(r'/+$'), '');
}
