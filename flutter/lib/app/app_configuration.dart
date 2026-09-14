/// A safe error: never retains the rejected value, which may contain secrets.
class AppConfigurationException implements Exception {
  const AppConfigurationException();

  @override
  String toString() => 'Invalid API origin configuration';
}

class AppConfiguration {
  const AppConfiguration._(this.apiHost);

  factory AppConfiguration.fromEnvironment(
    Map<String, String> environment, {
    String apiHostOverride = '',
  }) {
    final host =
        (apiHostOverride.isNotEmpty
                ? apiHostOverride
                : environment['API_HOST'] ?? '')
            .trim()
            .replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(host);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9.\[\]:-]+$').hasMatch(uri.host) ||
        host.contains('@') ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const AppConfigurationException();
    }
    return AppConfiguration._(uri.toString());
  }

  final String apiHost;
}
