
abstract class CacheEntity {
  int get isarId;

  CacheEntity({this.keepAlive = false, this.hits = 1, required this.ttl, required this.onlySession});

  final DateTime ttl;

  final int hits;

  final bool keepAlive;

  final bool onlySession;

  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession});
}
