import 'package:buff_lisa/data/config/api_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web resolves the API host to the current page origin', () {
    expect(
      resolveApiHost(
        isWeb: true,
        currentUri: Uri.parse('https://app.example.test/groups/123'),
        configuredHost: 'https://api.example.test',
      ),
      'https://app.example.test',
    );
  });

  test('web preserves a development port on the current page origin', () {
    expect(
      resolveApiHost(
        isWeb: true,
        currentUri: Uri.parse('http://127.0.0.1:4173/'),
        configuredHost: 'http://127.0.0.1:8181',
      ),
      'http://127.0.0.1:4173',
    );
  });

  test('native uses the configured host and removes trailing slashes', () {
    expect(
      resolveApiHost(
        isWeb: false,
        currentUri: Uri.parse('file:///app'),
        configuredHost: 'https://api.example.test///',
      ),
      'https://api.example.test',
    );
  });
}
