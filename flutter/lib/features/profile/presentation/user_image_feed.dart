import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class UserImageFeed extends ConsumerWidget {
  const UserImageFeed({
    super.key,
    required this.index,
    required this.userId,
    required this.userPinNotifier,
  });

  final int index;
  final String userId;
  final ProviderListenable<AsyncValue<List<PinEntity>>> userPinNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("User images")),
      body: ref
          .read(userPinNotifier)
          .when(
            data: (data) => CustomFeed(
              pinProvider: userPinNotifier,
              index: index,
              pagingController: PagingController.fromValue(
                PagingState<int, PinEntity>(
                  nextPageKey: index + 1,
                  itemList: data.getRange(0, index + 1).toList(),
                ),
                firstPageKey: 0,
              ),
            ),
            error: (error, stackTrace) => const Icon(Icons.error),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }
}
