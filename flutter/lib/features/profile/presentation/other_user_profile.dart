import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/profile/presentation/pop_up_menu_other_user.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class OtherUserProfile extends ConsumerWidget {
  const OtherUserProfile({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPins = ref.watch(pinUserServiceProvider(userId));
    final username = ref.watch(userByIdUsernameProvider(userId));
    final description = ref.watch(userByIdDescriptionProvider(userId));
    final bestSeason = ref.watch(userByIdBestSeasonProvider(userId));
    final selectedBatch = ref.watch(userByIdSelectedBatchProvider(userId));
    final profileImage = ref.watch(getUserProfileProvider(userId));
    final likes = ref.watch(userLikeServiceProvider(userId));
    return CustomAvatarScaffold(
      avatar: AsyncData(profileImage.value),
      title: Row(
        children: [
          Text(
            username.value ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          if (selectedBatch.value != null)
            Batch(batchId: selectedBatch.value!, fontSize: 10),
        ],
      ),
      actions: [PopUpMenuOtherUser(userId: userId)],
      profileQuickViewBoxes: _buildQuickStats(userPins, likes),
      boxes: [
        if (description.value != null)
          SliverToBoxAdapter(
            child: ListTile(
              title: const Text(
                "Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                description.value!,
                softWrap: true,
                maxLines: 10,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        if (bestSeason.value != null)
          SliverToBoxAdapter(child: SeasonTile(bestSeason: bestSeason.value!)),
      ],
      body: ImageGrid(pinProvider: pinUserServiceProvider(userId)),
    );
  }

  Widget _buildQuickStats(
    AsyncValue<List<PinEntity>> userPins,
    AsyncValue<UserLikesDto> likes,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(
          'Sticks',
          userPins.whenOrNull(data: (pins) => pins.length.toString()) ?? '---',
        ),
        _statItem('Likes', likes.value?.likeCount.toString() ?? '-'),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
