import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/geojson_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'geo_json_repository.g.dart';

@riverpod
int? zoomGeoLevel(Ref ref) {
  final zoom = ref.watch(mapZoomLevelProvider);
  if (zoom >= 11) {
    return 2;
  } else if (zoom >= 6) {
    return 1;
  } else if (zoom >= 3) {
    return 0;
  } else {
    return -1;
  }
}

@riverpod
(String? gid, String? name) zoomGid(Ref ref) {
  final zoom = ref.watch(zoomGeoLevelProvider);
  final region = ref.watch(districtServiceProvider);
  if (zoom == null) return (null, null);
  
  if (zoom == -1) {
    return ("world", "World");
  } else if (zoom == 0) {
    return (region?.gid0, region?.name0);
  } else if (zoom == 1) {
    return (region?.gid1, region?.name1);
  } else if (zoom == 2) {
    return (region?.gid2, region?.name2);
  } else {
    return (null, null);
  }
}



@riverpod
Future<List<GroupRankingDtoInner>?> groupRanking(Ref ref, String gid) async {
  final rankingApi = ref.watch(rankingApiProvider);
  final zoomLevel = ref.watch(zoomGeoLevelProvider);
  
  if (zoomLevel == null) return [];

  // --- Rate Limiting (Debounce) ---
  bool isCancelled = false;
  // If `zoomLevel` changes or the widget unmounts, this provider instance is disposed.
  ref.onDispose(() => isCancelled = true);

  // Wait for 2 seconds before making the network request.
  await Future<void>.delayed(const Duration(seconds: 1));

  // If the provider was disposed during the wait, abort the API call.
  if (isCancelled) return null;
  // --------------------------------

  if (zoomLevel == -1) {
    return await rankingApi.groupRanking();
  } else if (zoomLevel == 0) {
    return await rankingApi.groupRanking(gid0: gid);
  } else if (zoomLevel == 1) {
    return await rankingApi.groupRanking(gid1: gid);
  } else if (zoomLevel == 2) {
    return await rankingApi.groupRanking(gid2: gid);
  } else {
    return [];
  }
}

@riverpod
Future<List<UserRankingDtoInner>?> userRanking(Ref ref, String gid) async {
  final rankingApi = ref.watch(rankingApiProvider);
  final zoomLevel = ref.watch(zoomGeoLevelProvider);
  
  if (zoomLevel == null) return [];

  // --- Rate Limiting (Debounce) ---
  bool isCancelled = false;
  ref.onDispose(() => isCancelled = true);

  await Future<void>.delayed(const Duration(seconds: 1));

  if (isCancelled) return null;
  // --------------------------------

  if (zoomLevel == -1) {
    return await rankingApi.userRanking();
  } else if (zoomLevel == 0) {
    return await rankingApi.userRanking(gid0: gid);
  } else if (zoomLevel == 1) {
    return await rankingApi.userRanking(gid1: gid);
  } else if (zoomLevel == 2) {
    return await rankingApi.userRanking(gid2: gid);
  } else {
    return [];
  }
}
