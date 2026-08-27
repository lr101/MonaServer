import 'dart:typed_data';

import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';


// 1. Define your entity types
enum ImageType {
  pin,
  user,
  userSmall,
  group,
  groupSmall,
  groupPin
}

class ImageEntity extends CacheEntity {
  @override
  int get isarId => fastHash('${type.name}_$id');

  final String id;
  
  final ImageType type;
  
  final Uint8List? image;

  ImageEntity({
    required this.id,
    required this.type, // Require the type in the constructor
    required this.image,
    super.keepAlive = false,
    super.hits,
    required super.ttl,
    required super.onlySession
  });

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return ImageEntity(
      id: id,
      type: type, // Ensure type is preserved on copy
      image: image,
      keepAlive: keepAlive ?? this.keepAlive,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession
    );
  }
}
