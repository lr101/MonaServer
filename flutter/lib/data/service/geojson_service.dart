
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'geojson_service.g.dart';

@Riverpod(keepAlive: true)
class DistrictService extends _$DistrictService {
  
  double _lat = 0;
  double _long = 0;
  double _zoom = 0;
  double? _latitudeNew;
  double? _longitudeNew;
  late RankingApi rankingApi;
  final Logger _logger = Logger();
  
  // --- Mutex State ---
  bool _isFetching = false;
  bool _hasPendingRequest = false;

  @override
  MapInfoDto? build()  {
    rankingApi = ref.watch(rankingApiProvider);
    return null;
  }

  Future<void> updateLatLong(double latitude, double longitude, double zoom) async {
    _latitudeNew = latitude;
    _longitudeNew = longitude;
    _zoom = zoom;
  }

  double calculatedPrecision(double zoom) => 1.454 - (0.0908 * zoom).clamp(0.005, 2.0);

  Future<void> refetch() async {
    if (_latitudeNew == null || _longitudeNew == null) return;

    // 1. If we are currently fetching, flag that a new request came in and exit.
    if (_isFetching) {
      _hasPendingRequest = true;
      return;
    }

    // 2. Lock the mutex and clear any pending flags.
    _isFetching = true;
    _hasPendingRequest = false;

    try {
      // Extracting the actual work makes the mutex logic easier to read
      await _performFetch();
    } finally {
      // 3. Unlock the mutex. (Using 'finally' ensures it unlocks even if the API throws an error!)
      _isFetching = false;
      
      // 4. If the user moved the map WHILE we were fetching, trigger the last scheduled request.
      // Because updateLatLong updates the class variables, this will naturally use the newest coordinates.
      if (_hasPendingRequest) {
        _hasPendingRequest = false;
        refetch(); 
      }
    }
  }

  // Moved your core logic here
  Future<void> _performFetch() async {
    final precision = calculatedPrecision(_zoom);
  
    // Check if we moved enough to warrant a fetch
    if (((_latitudeNew! - _lat).abs() > precision) ||
        (_longitudeNew! - _long).abs() > precision) {
      
      _lat = _latitudeNew!;
      _long = _longitudeNew!;
      
      final rankingApi = ref.read(rankingApiProvider); 
      
      try {
        final mapInfo = await rankingApi.getMapInfo(
          latitude: _lat, 
          longitude: _long,
        );
        _logger.i("Fetched map info: $mapInfo");
        
        if (mapInfo != null && mapInfo.isNotEmpty &&
            state?.gid2 != mapInfo.first.gid2) {
          state = mapInfo.first;
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }
}
