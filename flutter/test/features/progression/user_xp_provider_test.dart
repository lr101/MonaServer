import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'does not request XP for a user other than the signed-in account',
    () async {
      final container = ProviderContainer(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'signed-in-user',
              refreshToken: 'refresh-token',
              cameras: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final xp = await container.read(userXpProvider('another-user').future);

      expect(xp, isNull);
    },
  );
}
