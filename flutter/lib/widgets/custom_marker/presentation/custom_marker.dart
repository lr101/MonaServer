import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CustomMarkerWidget extends Marker {

  final PinEntity pinDto;
  final bool withAnimation;


  CustomMarkerWidget({required this.pinDto, this.withAnimation = false}) : super(
    point: LatLng(pinDto.latitude, pinDto.longitude),
    child: CustomMarkerContent(pinDto: pinDto, withAnimation: withAnimation),
    width: 80,
    height: 80,
  );

}
