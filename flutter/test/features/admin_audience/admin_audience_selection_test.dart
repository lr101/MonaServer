import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selected IDs survive pagination and produce an actionable audience',
    () {
      final selection = AdminAudienceSelectionModel();

      selection.toggleSelected('user-1');
      selection.toggleSelected('user-2');

      expect(selection.selectedIds, {'user-1', 'user-2'});
      expect(
        selection.audience,
        AdminAudienceSelection.selected({'user-1', 'user-2'}),
      );
      expect(selection.audience.isActionable, isTrue);
    },
  );

  test('changing the matching filter invalidates selected IDs', () {
    final selection = AdminAudienceSelectionModel();
    selection.toggleSelected('user-1');

    selection.setFilter(const AdminAudienceFilter(search: 'alice'));

    expect(selection.selectedIds, isEmpty);
    expect(
      selection.audience,
      AdminAudienceSelection.filter(const AdminAudienceFilter(search: 'alice')),
    );
    expect(selection.filterRevision, 1);
  });

  test(
    'all matching is explicit and cannot be confused with an empty selection',
    () {
      final selection = AdminAudienceSelectionModel();

      selection.selectAllMatching();

      expect(selection.audience.kind, AdminAudienceSelectionKind.all);
      expect(selection.audience.isActionable, isTrue);
      expect(selection.audience.summary, 'All eligible accounts');
    },
  );

  test('clearing selection returns a non-actionable selected audience', () {
    final selection = AdminAudienceSelectionModel();
    selection.toggleSelected('user-1');

    selection.clear();

    expect(selection.audience.kind, AdminAudienceSelectionKind.selected);
    expect(selection.audience.isActionable, isFalse);
  });
}
