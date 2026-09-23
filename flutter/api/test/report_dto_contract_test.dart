import 'package:openapi/api.dart';
import 'package:test/test.dart';

void main() {
  test('ReportDto serializes and deserializes nullable target identity', () {
    final dto = ReportDto(
      userId: '00000000-0000-0000-0000-000000000001',
      report: 'Bug',
      message: 'details',
      targetId: '00000000-0000-0000-0000-000000000002',
      targetKind: 'pin',
    );

    final json = dto.toJson();
    expect(json['targetId'], dto.targetId);
    expect(json['targetKind'], dto.targetKind);

    final decoded = ReportDto.fromJson(json);
    expect(decoded, dto);
  });

  test('ReportDto accepts legacy payloads without target identity', () {
    final decoded = ReportDto.fromJson(<String, dynamic>{
      'userId': '00000000-0000-0000-0000-000000000001',
      'report': 'Bug',
      'message': 'details',
    });

    expect(decoded, isNotNull);
    expect(decoded!.targetId, isNull);
    expect(decoded.targetKind, isNull);
  });
}
