import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';

class UserProfile extends ConsumerWidget {
  const UserProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(userIdProvider);
    final userPins = ref.watch(pinUserServiceProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final likes = ref.watch(userLikeServiceProvider(userId));
    final profileImage = ref.watch(getUserProfileProvider(userId));

    return CustomAvatarScaffold(
      avatar: profileImage,
      title: _buildTitle(currentUser),
      actions: _buildActions(context),
      hasBackButton: false,
      profileQuickViewBoxes: _buildQuickStats(userPins, ref),
      boxes: _buildDetailList(currentUser, likes),
      body: ImageGrid(pinProvider: pinUserServiceProvider(userId)),
    );
  }

  Widget _buildTitle(AsyncValue<UserEntity?> currentUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            currentUser.value?.username ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        if (currentUser.value?.selectedBatch != null)
          GestureDetector(
            child: Batch(
              batchId: currentUser.value!.selectedBatch!,
              fontSize: 10,
            ),
            onTap: () => navigatorKey.currentContext?.pushNamed("achievements"),
          ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => context.pushNamed("achievements"),
        icon: const Icon(Icons.emoji_events),
      ),
      IconButton(
        onPressed: () => context.pushNamed("settings"),
        icon: const Icon(Icons.settings),
      ),
    ];
  }

  Widget _buildQuickStats(AsyncValue<dynamic> userPins, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(
          "Sticks",
          userPins.whenOrNull(data: (d) => d.length.toString()) ?? "---",
        ),
        _statItem(
          "Groups",
          ref.watch(userGroupServiceProvider).value?.length.toString() ?? "---",
        ),
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

  List<SliverToBoxAdapter> _buildDetailList(
    AsyncValue<UserEntity?> currentUser,
    AsyncValue<UserLikesDto> likes,
  ) {
    return [
      if (currentUser.value?.description != null)
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Description",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              currentUser.value!.description!,
              softWrap: true,
              maxLines: 10,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      if (currentUser.value?.bestSeason != null)
        SliverToBoxAdapter(
          child: SeasonTile(bestSeason: currentUser.value!.bestSeason!),
        ),
      SliverToBoxAdapter(
        child: ListTile(
          title: const Text(
            "Likes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            likes.value?.likeCount.toString() ?? "-",
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),
    ];
  }
}
