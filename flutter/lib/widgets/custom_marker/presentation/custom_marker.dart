import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CustomMarkerWidget extends Marker {
  final PinEntity pinDto;

  CustomMarkerWidget({required this.pinDto})
    : super(
        point: LatLng(pinDto.latitude, pinDto.longitude),
        child: CustomMarkerContent(pinDto: pinDto),
        width: 48,
        height: 56,
        alignment: Alignment.topCenter,
      );
}
