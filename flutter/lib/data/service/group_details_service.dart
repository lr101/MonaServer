import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GroupMediaStatus { loading, available, unavailable, failed }

class GroupDetailsState {
  const GroupDetailsState({
    required this.group,
    required this.pins,
    required this.profileImage,
  });

  final GroupEntity? group;
  final AsyncValue<List<PinEntity>> pins;
  final AsyncValue<Uint8List?> profileImage;

  GroupMediaStatus get mediaStatus {
    if (profileImage.isLoading) return GroupMediaStatus.loading;
    if (profileImage.hasError) return GroupMediaStatus.failed;
    if (profileImage.value == null) return GroupMediaStatus.unavailable;
    return GroupMediaStatus.available;
  }
}

AsyncValue<List<PinEntity>> _selectGroupPins(
  AsyncValue<GroupDetailsState> details,
) {
  return details.when(
    data: (state) => state.pins,
    loading: () => const AsyncLoading<List<PinEntity>>(),
    error: (error, stackTrace) =>
        AsyncError<List<PinEntity>>(error, stackTrace),
  );
}

final groupDetailsProvider = StreamProvider.autoDispose
    .family<GroupDetailsState, String>((ref, groupId) {
      // A single-subscription controller buffers values until Riverpod
      // attaches to the stream. The upstream listeners below can emit during
      // provider construction, so a broadcast controller would drop the
      // initial details state.
      final controller = StreamController<GroupDetailsState>();
      GroupEntity? group;
      var metadataReady = false;
      var metadataFailed = false;
      AsyncValue<List<PinEntity>> pins = const AsyncLoading();
      AsyncValue<Uint8List?> profileImage = const AsyncLoading();

      void emit() {
        if (!metadataReady || metadataFailed || controller.isClosed) return;
        controller.add(
          GroupDetailsState(
            group: group,
            pins: pins,
            profileImage: profileImage,
          ),
        );
      }

      ref.listen(groupMetadataProvider(groupId), (_, next) {
        next.when(
          data: (metadata) {
            group = metadata;
            metadataReady = true;
            emit();
          },
          loading: () {},
          error: (error, stackTrace) {
            if (controller.isClosed) return;
            metadataFailed = true;
            controller.addError(error, stackTrace);
            unawaited(controller.close());
          },
        );
      }, fireImmediately: true);
      ref.listen(pinGroupServiceProvider(groupId), (_, next) {
        pins = next;
        emit();
      }, fireImmediately: true);
      ref.listen(groupProfilePictureByIdProvider(groupId), (_, next) {
        profileImage = next;
        emit();
      }, fireImmediately: true);

      ref.onDispose(() {
        unawaited(controller.close());
      });
      return controller.stream;
    });

final groupDetailsPinsProvider = Provider.autoDispose
    .family<AsyncValue<List<PinEntity>?>, String>((ref, groupId) {
      final pins = ref.watch(
        groupDetailsProvider(groupId).select(_selectGroupPins),
      );
      return pins.when(
        data: (values) {
          final sorted = values.toList()
            ..sort((a, b) => b.creationDate.compareTo(a.creationDate));
          return AsyncData<List<PinEntity>?>(sorted);
        },
        loading: () => const AsyncLoading<List<PinEntity>?>(),
        error: (error, stackTrace) =>
            AsyncError<List<PinEntity>?>(error, stackTrace),
      );
    });

/// Compatibility projection for consumers that only need the group entity.
final groupDetailsReadyProvider = StreamProvider.autoDispose
    .family<GroupEntity?, String>((ref, groupId) {
      final controller = StreamController<GroupEntity?>();
      ref.listen<AsyncValue<GroupDetailsState>>(groupDetailsProvider(groupId), (
        _,
        next,
      ) {
        next.when(
          data: (details) => controller.add(details.group),
          loading: () {},
          error: controller.addError,
        );
      }, fireImmediately: true);
      ref.onDispose(() {
        unawaited(controller.close());
      });
      return controller.stream;
    });
