import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

bool isPinWithinPresenceRange(Position? userPosition, PinEntity pin) {
  if (userPosition == null) return false;
  return const Distance().as(
        LengthUnit.Meter,
        LatLng(userPosition.latitude, userPosition.longitude),
        LatLng(pin.latitude, pin.longitude),
      ) <=
      50;
}

class PinPresenceControl extends StatelessWidget {
  const PinPresenceControl({
    super.key,
    required this.pin,
    required this.userPosition,
    required this.isSaving,
    required this.onToggle,
    this.showStatusMessage = true,
  });

  final PinEntity pin;
  final Position? userPosition;
  final bool isSaving;
  final bool showStatusMessage;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final nearby = isPinWithinPresenceRange(userPosition, pin);
    final canUpdate = pin.lastSynced != null && nearby && !isSaving;
    final statusText = pin.lastSynced == null
        ? 'Upload this pin before updating its presence'
        : pin.isGone
        ? nearby
              ? 'Marked gone · shown grey on the map'
              : 'Marked gone · get within 50 m to update'
        : nearby
        ? 'Marked as still here'
        : 'Get within 50 m to update this pin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canUpdate ? onToggle : null,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  pin.isGone
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                ),
          label: Text(pin.isGone ? 'Mark as here' : 'Mark as gone'),
        ),
        if (showStatusMessage && !canUpdate && !isSaving) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}
