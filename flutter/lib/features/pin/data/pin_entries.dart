import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

int countUniqueContributedSticks(Iterable<PinEntity> entries) =>
    entries.map((entry) => entry.pinId).toSet().length;
final profilePhotoHistoryRevisionProvider = StreamProvider<int>(
  (ref) => ref
      .watch(photoLibraryProvider)
      .changes
      .map((_) => DateTime.now().microsecondsSinceEpoch),
);

/// Projects photographs into posts while retaining one PinEntity per map place.
List<PinEntity> buildPinEntries(
  List<PinEntity> pins,
  Map<String, List<PinPhotoDto>> photosByPin, {
  String? contributorId,
  Set<String> hiddenUserIds = const {},
}) {
  final entries = <PinEntity>[];
  for (final pin in pins) {
    if (!hiddenUserIds.contains(pin.creator) &&
        (contributorId == null || pin.creator == contributorId)) {
      entries.add(pin);
    }
    for (final photo in photosByPin[pin.pinId] ?? const <PinPhotoDto>[]) {
      if (photo.isOriginal ||
          (photo.contributorId != null &&
              hiddenUserIds.contains(photo.contributorId)) ||
          (contributorId != null && photo.contributorId != contributorId)) {
        continue;
      }
      entries.add(pin.withPhotoUpdate(photo));
    }
  }
  entries.sort((a, b) {
    final byDate = b.creationDate.compareTo(a.creationDate);
    return byDate != 0 ? byDate : b.entryId.compareTo(a.entryId);
  });
  return entries;
}

Stream<List<PinEntity>> _gallery(Ref ref, PhotoScope scope) {
  final owner = ref.watch(photoLibraryProvider);
  final hiddenPins = ref.watch(hiddenPostsServiceProvider).toSet();
  final hiddenUsers = ref.watch(hiddenUserServiceProvider).toSet();
  return owner
      .watchGallery(scope)
      .transform(
        StreamTransformer.fromHandlers(
          handleData: (snapshot, sink) {
            final error = snapshot.error;
            final entries = owner
                .entries(scope)
                .where(
                  (p) =>
                      !hiddenPins.contains(p.pinId) &&
                      !hiddenUsers.contains(p.creator) &&
                      !hiddenUsers.contains(owner.parent(p.pinId)?.creator),
                )
                .toList();
            if (error is ApiException && [403, 404].contains(error.code)) {
              sink.add([]);
              return;
            }
            if (error != null && entries.isEmpty) {
              sink.addError(error);
              return;
            }
            if (entries.isEmpty && !snapshot.loaded) return;
            sink.add(entries);
          },
        ),
      );
}

final userPinEntriesProvider = StreamProvider.family<List<PinEntity>, String>(
  (ref, id) => _gallery(ref, PhotoScope(userId: id)),
  retry: (_, _) => null,
);
final profileGridEntriesProvider = userPinEntriesProvider;
final groupPinEntriesProvider = StreamProvider.family<List<PinEntity>, String>(
  (ref, id) => _gallery(ref, PhotoScope(groupId: id)),
  retry: (_, _) => null,
);
final activePinEntriesProvider = StreamProvider<List<PinEntity>>((ref) {
  final owner = ref.watch(photoLibraryProvider);
  final pins = ref.watch(sortedActivatedPinsProvider).value ?? <PinEntity>[];
  final hiddenPins = ref.watch(hiddenPostsServiceProvider).toSet();
  final hiddenUsers = ref.watch(hiddenUserServiceProvider).toSet();
  late StreamController<List<PinEntity>> stream;
  StreamSubscription<void>? sub;
  void emit() {
    stream.add(
      buildPinEntries(
        pins.where((p) => !hiddenPins.contains(p.pinId)).toList(),
        {for (final p in pins) p.pinId: owner.history(p.pinId)},
        hiddenUserIds: hiddenUsers,
      ),
    );
  }

  stream = StreamController(
    onListen: () {
      sub = owner.changes.listen((_) => emit());
      unawaited(() async {
        await owner.hydrate();
        emit();
      }());
    },
    onCancel: () async {
      await sub?.cancel();
    },
  );
  return stream.stream;
});
