import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

PinEntity entry(String id) => PinEntity(
  pinId: id,
  latitude: 0,
  longitude: 0,
  creationDate: DateTime.utc(2026),
  creator: 'u',
  groupId: 'g',
  ttl: DateTime.utc(2026),
  onlySession: false,
);
void main() {
  test('insertion before selected photo preserves loaded order and remaining pagination', () {
    final result = reconcileFeedEntries(
      [entry('a'), entry('b'), entry('c')],
      [entry('new'), entry('a'), entry('b'), entry('c')],
      2,
    );
    expect(result.map((p) => p.entryId), ['a', 'b', 'new', 'c']);
  });
  test(
    'confirmed deletion removes its entry without losing other loaded items',
    () {
      final result = reconcileFeedEntries(
        [entry('a'), entry('b'), entry('c')],
        [entry('b'), entry('c')],
        2,
      );
      expect(result.map((p) => p.entryId), ['b', 'c']);
    },
  );
}
