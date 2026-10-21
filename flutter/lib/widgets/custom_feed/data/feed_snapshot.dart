import 'package:buff_lisa/data/entity/pin_entity.dart';

/// Keep already mounted entries in their current order while replacing their
/// metadata. New photos join the unmounted tail, preserving the scroll anchor.
List<PinEntity> reconcileFeedEntries(
  List<PinEntity> previous,
  List<PinEntity> next,
  int loadedCount,
) {
  final byId = {for (final item in next) item.entryId: item};
  final retained = <PinEntity>[];
  for (final item in previous.take(loadedCount)) {
    final replacement = byId.remove(item.entryId);
    if (replacement != null) retained.add(replacement);
  }
  return [...retained, ...next.where((item) => byId.containsKey(item.entryId))];
}
