import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

class MapPinDesign {
  const MapPinDesign({
    required this.style,
    required this.name,
    required this.shape,
    required this.bodyColor,
    required this.outlineColor,
    required this.outlineWidth,
    required this.imageInset,
    required this.imageZoom,
    required this.imageAlignmentX,
    required this.imageAlignmentY,
    required this.imageBorderColor,
    required this.badge,
  });

  final String style;
  final String name;
  final String shape;
  final Color bodyColor;
  final Color outlineColor;
  final double outlineWidth;
  final double imageInset;
  final double imageZoom;
  final double imageAlignmentX;
  final double imageAlignmentY;
  final Color imageBorderColor;
  final String badge;

  factory MapPinDesign.fromDto(GroupPinDesignDto dto) => MapPinDesign(
    style: dto.style.value,
    name: dto.name,
    shape: dto.shape.value,
    bodyColor: _color(dto.bodyColor),
    outlineColor: _color(dto.outlineColor),
    outlineWidth: dto.outlineWidth.toDouble(),
    imageInset: dto.imageInset.toDouble(),
    imageZoom: dto.imageZoom.toDouble(),
    imageAlignmentX: dto.imageAlignmentX.toDouble(),
    imageAlignmentY: dto.imageAlignmentY.toDouble(),
    imageBorderColor: _color(dto.imageBorderColor),
    badge: dto.badge.value,
  );

  factory MapPinDesign.forStyle(String style) {
    final normalized = switch (style) {
      'moss' => (
        'Moss',
        const Color(0xff668465),
        'teardrop',
        const Color(0xffd6eacd),
      ),
      'sunset' => (
        'Sunset',
        const Color(0xffd57b50),
        'circle',
        const Color(0xff5a2f54),
      ),
      'aurora' => (
        'Aurora',
        const Color(0xff6d77ba),
        'shield',
        const Color(0xffc4f4ef),
      ),
      'seafoam' => (
        'Seafoam',
        const Color(0xff4f9a91),
        'circle',
        const Color(0xffd6f3e9),
      ),
      'honey' => (
        'Honey',
        const Color(0xffd69b2d),
        'teardrop',
        const Color(0xfffff1c2),
      ),
      'orchid' => (
        'Orchid',
        const Color(0xff8855a5),
        'shield',
        const Color(0xffeddaf7),
      ),
      'copper' => (
        'Copper',
        const Color(0xffa85b3b),
        'teardrop',
        const Color(0xffffdcc5),
      ),
      'jade' => (
        'Jade',
        const Color(0xff388e67),
        'circle',
        const Color(0xffd4f0dc),
      ),
      'ember' => (
        'Ember',
        const Color(0xffc74c3d),
        'teardrop',
        const Color(0xffffd6c8),
      ),
      'glacier' => (
        'Glacier',
        const Color(0xff4895b3),
        'circle',
        const Color(0xffd6f4ff),
      ),
      'rose' => (
        'Rose',
        const Color(0xffc35c84),
        'circle',
        const Color(0xfffde0eb),
      ),
      'midnight' => (
        'Midnight',
        const Color(0xff4d568e),
        'shield',
        const Color(0xffdde3ff),
      ),
      _ => ('Classic', const Color(0xff2457d6), 'circle', Colors.white),
    };
    return MapPinDesign(
      style: style,
      name: normalized.$1,
      shape: normalized.$3,
      bodyColor: normalized.$2,
      outlineColor: normalized.$4,
      outlineWidth: 2,
      imageInset: 2,
      imageZoom: 1,
      imageAlignmentX: 0,
      imageAlignmentY: 0,
      imageBorderColor: Colors.white,
      badge: switch (style) {
        'aurora' || 'ember' => 'spark',
        'honey' => 'sun',
        'orchid' || 'midnight' => 'star',
        _ => 'none',
      },
    );
  }

  factory MapPinDesign.forCatalog(
    GroupPinDesignCatalogDto? catalog,
    String style,
  ) {
    for (final design in catalog?.designs ?? const <GroupPinDesignDto>[]) {
      if (design.style.value == style) return MapPinDesign.fromDto(design);
    }
    return MapPinDesign.forStyle(style);
  }

  MapPinDesign copyWith({
    String? name,
    String? shape,
    Color? bodyColor,
    Color? outlineColor,
    double? outlineWidth,
    double? imageInset,
    double? imageZoom,
    double? imageAlignmentX,
    double? imageAlignmentY,
    Color? imageBorderColor,
    String? badge,
  }) => MapPinDesign(
    style: style,
    name: name ?? this.name,
    shape: shape ?? this.shape,
    bodyColor: bodyColor ?? this.bodyColor,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    imageInset: imageInset ?? this.imageInset,
    imageZoom: imageZoom ?? this.imageZoom,
    imageAlignmentX: imageAlignmentX ?? this.imageAlignmentX,
    imageAlignmentY: imageAlignmentY ?? this.imageAlignmentY,
    imageBorderColor: imageBorderColor ?? this.imageBorderColor,
    badge: badge ?? this.badge,
  );

  GroupPinDesignDto toDto() => GroupPinDesignDto(
    style: GroupPinDesignStyle.values.firstWhere(
      (value) => value.value == style,
    ),
    name: name,
    shape: GroupPinDesignShape.values.firstWhere(
      (value) => value.value == shape,
    ),
    bodyColor: _hex(bodyColor),
    outlineColor: _hex(outlineColor),
    outlineWidth: outlineWidth,
    imageInset: imageInset,
    imageZoom: imageZoom,
    imageAlignmentX: imageAlignmentX,
    imageAlignmentY: imageAlignmentY,
    imageBorderColor: _hex(imageBorderColor),
    badge: GroupPinDesignBadge.values.firstWhere(
      (value) => value.value == badge,
    ),
    shadow: true,
  );
}

Color _color(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  return Color(0xff000000 | int.parse(hex, radix: 16));
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
