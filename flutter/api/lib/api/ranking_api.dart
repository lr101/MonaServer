//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class RankingApi {
  RankingApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Gets the geojson info of a specific gid
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] gid2:
  ///   County ID. Only one allowed
  ///
  /// * [String] gid1:
  ///   State ID. Only one allowed
  ///
  /// * [String] gid0:
  ///   Country ID. Only one allowed
  Future<Response> getGeoJsonWithHttpInfo({ String? gid2, String? gid1, String? gid0, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/map/geojson';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (gid2 != null) {
      queryParams.addAll(_queryParams('', 'gid2', gid2));
    }
    if (gid1 != null) {
      queryParams.addAll(_queryParams('', 'gid1', gid1));
    }
    if (gid0 != null) {
      queryParams.addAll(_queryParams('', 'gid0', gid0));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Gets the geojson info of a specific gid
  ///
  /// Parameters:
  ///
  /// * [String] gid2:
  ///   County ID. Only one allowed
  ///
  /// * [String] gid1:
  ///   State ID. Only one allowed
  ///
  /// * [String] gid0:
  ///   Country ID. Only one allowed
  Future<List<String>?> getGeoJson({ String? gid2, String? gid1, String? gid0, }) async {
    final response = await getGeoJsonWithHttpInfo( gid2: gid2, gid1: gid1, gid0: gid0, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<String>') as List)
        .cast<String>()
        .toList(growable: false);

    }
    return null;
  }

  /// Performs an HTTP 'GET /api/v2/map' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [num] latitude:
  ///   Together with longitude an info dto of the position can be requested.
  ///
  /// * [num] longitude:
  ///   Together with latitude an info dto of the position can be requested.
  Future<Response> getMapInfoWithHttpInfo({ num? latitude, num? longitude, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/map';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (latitude != null) {
      queryParams.addAll(_queryParams('', 'latitude', latitude));
    }
    if (longitude != null) {
      queryParams.addAll(_queryParams('', 'longitude', longitude));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Parameters:
  ///
  /// * [num] latitude:
  ///   Together with longitude an info dto of the position can be requested.
  ///
  /// * [num] longitude:
  ///   Together with latitude an info dto of the position can be requested.
  Future<List<MapInfoDto>?> getMapInfo({ num? latitude, num? longitude, }) async {
    final response = await getMapInfoWithHttpInfo( latitude: latitude, longitude: longitude, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<MapInfoDto>') as List)
        .cast<MapInfoDto>()
        .toList(growable: false);

    }
    return null;
  }

  /// Performs an HTTP 'GET /api/v2/ranking/group' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] gid0:
  ///   Country ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid1:
  ///   State ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid2:
  ///   County ID. When not null the ranking by country is returned.
  ///
  /// * [DateTime] since:
  ///   Only include pins added since this point in time. When null all pins are included
  ///
  /// * [bool] season:
  ///   Only include pins from this season. When null all pins are included
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<Response> groupRankingWithHttpInfo({ String? gid0, String? gid1, String? gid2, DateTime? since, bool? season, int? page, int? size, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/ranking/group';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (gid0 != null) {
      queryParams.addAll(_queryParams('', 'gid0', gid0));
    }
    if (gid1 != null) {
      queryParams.addAll(_queryParams('', 'gid1', gid1));
    }
    if (gid2 != null) {
      queryParams.addAll(_queryParams('', 'gid2', gid2));
    }
    if (since != null) {
      queryParams.addAll(_queryParams('', 'since', since));
    }
    if (season != null) {
      queryParams.addAll(_queryParams('', 'season', season));
    }
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }
    if (size != null) {
      queryParams.addAll(_queryParams('', 'size', size));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Parameters:
  ///
  /// * [String] gid0:
  ///   Country ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid1:
  ///   State ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid2:
  ///   County ID. When not null the ranking by country is returned.
  ///
  /// * [DateTime] since:
  ///   Only include pins added since this point in time. When null all pins are included
  ///
  /// * [bool] season:
  ///   Only include pins from this season. When null all pins are included
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<List<GroupRankingDtoInner>?> groupRanking({ String? gid0, String? gid1, String? gid2, DateTime? since, bool? season, int? page, int? size, }) async {
    final response = await groupRankingWithHttpInfo( gid0: gid0, gid1: gid1, gid2: gid2, since: since, season: season, page: page, size: size, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<GroupRankingDtoInner>') as List)
        .cast<GroupRankingDtoInner>()
        .toList(growable: false);

    }
    return null;
  }

  /// Search for a location
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] search:
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<Response> searchRankingWithHttpInfo({ String? search, int? page, int? size, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/ranking/search';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (search != null) {
      queryParams.addAll(_queryParams('', 'search', search));
    }
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }
    if (size != null) {
      queryParams.addAll(_queryParams('', 'size', size));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Search for a location
  ///
  /// Parameters:
  ///
  /// * [String] search:
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<List<RankingSearchDtoInner>?> searchRanking({ String? search, int? page, int? size, }) async {
    final response = await searchRankingWithHttpInfo( search: search, page: page, size: size, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<RankingSearchDtoInner>') as List)
        .cast<RankingSearchDtoInner>()
        .toList(growable: false);

    }
    return null;
  }

  /// Performs an HTTP 'GET /api/v2/ranking/user' operation and returns the [Response].
  /// Parameters:
  ///
  /// * [String] gid0:
  ///   Country ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid1:
  ///   State ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid2:
  ///   County ID. When not null the ranking by country is returned.
  ///
  /// * [DateTime] since:
  ///   Only include pins added since this point in time. When null all pins are included
  ///
  /// * [bool] season:
  ///   Only include pins from this season. When null all pins are included
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<Response> userRankingWithHttpInfo({ String? gid0, String? gid1, String? gid2, DateTime? since, bool? season, int? page, int? size, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/ranking/user';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (gid0 != null) {
      queryParams.addAll(_queryParams('', 'gid0', gid0));
    }
    if (gid1 != null) {
      queryParams.addAll(_queryParams('', 'gid1', gid1));
    }
    if (gid2 != null) {
      queryParams.addAll(_queryParams('', 'gid2', gid2));
    }
    if (since != null) {
      queryParams.addAll(_queryParams('', 'since', since));
    }
    if (season != null) {
      queryParams.addAll(_queryParams('', 'season', season));
    }
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }
    if (size != null) {
      queryParams.addAll(_queryParams('', 'size', size));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Parameters:
  ///
  /// * [String] gid0:
  ///   Country ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid1:
  ///   State ID. When not null the ranking by country is returned.
  ///
  /// * [String] gid2:
  ///   County ID. When not null the ranking by country is returned.
  ///
  /// * [DateTime] since:
  ///   Only include pins added since this point in time. When null all pins are included
  ///
  /// * [bool] season:
  ///   Only include pins from this season. When null all pins are included
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  Future<List<UserRankingDtoInner>?> userRanking({ String? gid0, String? gid1, String? gid2, DateTime? since, bool? season, int? page, int? size, }) async {
    final response = await userRankingWithHttpInfo( gid0: gid0, gid1: gid1, gid2: gid2, since: since, season: season, page: page, size: size, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<UserRankingDtoInner>') as List)
        .cast<UserRankingDtoInner>()
        .toList(growable: false);

    }
    return null;
  }
}
