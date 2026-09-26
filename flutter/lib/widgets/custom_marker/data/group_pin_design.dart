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
    required this.shadow,
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
  final bool shadow;

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
    shadow: dto.shadow,
  );

  factory MapPinDesign.forStyle(String style) {
    final normalized = switch (style) {
      'moss' => ('Moss', const Color(0xff668465), 'leaf'),
      'sunset' => ('Sunset', const Color(0xffd57b50), 'sun'),
      'aurora' => ('Aurora', const Color(0xff6d77ba), 'spark'),
      _ => ('Classic', const Color(0xff2457d6), 'none'),
    };
    return MapPinDesign(
      style: style,
      name: normalized.$1,
      shape: 'circle',
      bodyColor: normalized.$2,
      outlineColor: Colors.white,
      outlineWidth: 2,
      imageInset: 2,
      imageZoom: 1,
      imageAlignmentX: 0,
      imageAlignmentY: 0,
      imageBorderColor: Colors.white,
      badge: normalized.$3,
      shadow: true,
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
    bool? shadow,
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
    shadow: shadow ?? this.shadow,
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
    shadow: shadow,
  );
}

Color _color(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  return Color(0xff000000 | int.parse(hex, radix: 16));
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
