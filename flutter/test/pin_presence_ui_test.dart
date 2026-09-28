import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('nearby range includes 50 meters and rejects farther pins', () {
    final pin = _pin();

    expect(isPinWithinPresenceRange(_position(50, 8), pin), isTrue);
    expect(isPinWithinPresenceRange(_position(50.001, 8), pin), isFalse);
    expect(isPinWithinPresenceRange(null, pin), isFalse);
  });

  testWidgets('presence action is enabled nearby and disabled when far away', (
    tester,
  ) async {
    var toggled = false;
    final pin = _pin();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPresenceControl(
            pin: pin,
            userPosition: _position(50, 8),
            isSaving: false,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );

    final nearbyButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(nearbyButton.onPressed, isNotNull);
    await tester.tap(find.text('Mark as gone'));
    expect(toggled, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPresenceControl(
            pin: pin,
            userPosition: _position(50.001, 8),
            isSaving: false,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Get within 50 m to update this pin'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('gone pin markers are grey and labeled for accessibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PinMarkerImage(isGone: true, image: Icon(Icons.place)),
          ),
        ),
      ),
    );

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Pin marked gone',
      ),
      findsOneWidget,
    );
  });
}

PinEntity _pin({bool isGone = false}) => PinEntity(
  pinId: 'pin',
  latitude: 50,
  longitude: 8,
  creationDate: DateTime.utc(2026),
  creator: 'user',
  groupId: 'group',
  isGone: isGone,
  lastSynced: DateTime.utc(2026),
  ttl: DateTime.utc(2099),
  onlySession: false,
);

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.utc(2026),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
