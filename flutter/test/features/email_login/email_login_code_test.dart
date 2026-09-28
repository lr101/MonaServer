import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts six alphanumeric sign-in codes case insensitively', () {
    final code = EmailLoginCode.tryParse(' a2b4c6 ');

    expect(code?.value, 'A2B4C6');
    expect(code.toString(), isNot(contains('A2B4C6')));
  });

  test('rejects codes that are not exactly six alphanumeric characters', () {
    expect(EmailLoginCode.tryParse('ABCDE'), isNull);
    expect(EmailLoginCode.tryParse('ABCDEFG'), isNull);
    expect(EmailLoginCode.tryParse('ABC-12'), isNull);
    expect(EmailLoginCode.tryParse('ſ2345a'), isNull);
  });
}
