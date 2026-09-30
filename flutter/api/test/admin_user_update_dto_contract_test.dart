import 'package:openapi/api.dart';
import 'package:test/test.dart';

void main() {
  test('admin permission updates preserve omitted versus empty lists', () {
    final unchanged = AdminUserUpdateDto(expectedAuthGeneration: 1);
    expect(unchanged.adminPermissions, isNull);
    expect(unchanged.toJson()['adminPermissions'], isNull);

    final clear = AdminUserUpdateDto(
      expectedAuthGeneration: 1,
      adminPermissions: const [],
    );
    expect(clear.toJson()['adminPermissions'], isEmpty);

    final decoded = AdminUserUpdateDto.fromJson(<String, dynamic>{
      'expectedAuthGeneration': 1,
    });
    expect(decoded!.adminPermissions, isNull);
  });
}
