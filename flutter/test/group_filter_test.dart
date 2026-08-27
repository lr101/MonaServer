import 'package:buff_lisa/widgets/group_selector/presentation/group_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorders an item to the adjusted destination index', () {
    expect(reorderGroupIds(['first', 'second', 'third'], 0, 2), [
      'second',
      'third',
      'first',
    ]);
  });

  test('reorders an item to the beginning of the list', () {
    expect(reorderGroupIds(['first', 'second', 'third'], 2, 0), [
      'third',
      'first',
      'second',
    ]);
  });
}
