import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test('finds local groups that are absent from the server sync', () {
    final response = SyncDto(
      groupUpdates: [
        SyncDtoGroupUpdatesInner(
          group: GroupDto(id: 'kept', name: 'Kept', visibility: 0),
        ),
      ],
    );

    expect(removedUserGroupIds(['kept', 'removed'], response), {'removed'});
  });
}
