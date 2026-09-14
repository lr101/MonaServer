import 'package:buff_lisa/data/config/api_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves the API host to the configured backend origin', () {
    expect(
      resolveApiHost(configuredHost: 'https://api.example.test'),
      'https://api.example.test',
    );
  });

  test('preserves the configured development port', () {
    expect(
      resolveApiHost(configuredHost: 'http://127.0.0.1:8181'),
      'http://127.0.0.1:8181',
    );
  });

  test('removes trailing slashes from the configured host', () {
    expect(
      resolveApiHost(configuredHost: 'https://api.example.test///'),
      'https://api.example.test',
    );
  });

  test('falls back to the production origin when configuration is empty', () {
    expect(
      resolveApiHost(configuredHost: '  '),
      'https://stick-it.lr-projects.de',
    );
  });
}
