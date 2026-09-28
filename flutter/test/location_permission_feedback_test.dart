import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'automatic location permission checks do not show a global snackbar',
    (tester) async {
      final originalPlatform = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _DeniedLocationPermission();
      addTearDown(() => GeolocatorPlatform.instance = originalPlatform);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionProvider.overrideWithValue(AccountSession(true)),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const _LocationReader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Map ready'), findsOneWidget);
      expect(
        find.text('Some functions do not work without location permission'),
        findsNothing,
      );
    },
  );
}

class _LocationReader extends ConsumerWidget {
  const _LocationReader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentLocationProvider);
    return const Scaffold(body: Text('Map ready'));
  }
}

class _DeniedLocationPermission extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.deniedForever;
}
