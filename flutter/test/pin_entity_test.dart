import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test('accepts integer and fractional coordinates from API JSON', () {
    for (final coordinates in [
      [50, 8],
      [50.125, 8.25],
    ]) {
      final dto = PinWithOptionalImageDto.fromJson({
        'id': 'pin',
        'creationDate': '2026-09-10T12:00:00Z',
        'latitude': coordinates[0],
        'longitude': coordinates[1],
        'creationUser': 'user',
        'groupId': 'group',
      })!;
      final pin = PinEntity.fromDto(dto, false);
      expect(pin.latitude, coordinates[0].toDouble());
      expect(pin.longitude, coordinates[1].toDouble());
    }
  });
}
