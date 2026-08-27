//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class LikesApi {
  LikesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create or update a like
  ///
  /// Create or update a like
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [CreateLikeDto] createLikeDto (required):
  Future<Response> createOrUpdateLikeWithHttpInfo(String pinId, CreateLikeDto createLikeDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins/{pinId}/likes'
      .replaceAll('{pinId}', pinId);

    // ignore: prefer_final_locals
    Object? postBody = createLikeDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Create or update a like
  ///
  /// Create or update a like
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [CreateLikeDto] createLikeDto (required):
  Future<PinLikeDto?> createOrUpdateLike(String pinId, CreateLikeDto createLikeDto,) async {
    final response = await createOrUpdateLikeWithHttpInfo(pinId, createLikeDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PinLikeDto',) as PinLikeDto;
    
    }
    return null;
  }

  /// Get pin likes
  ///
  /// Get pin likes
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  Future<Response> getPinLikesWithHttpInfo(String pinId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins/{pinId}/likes'
      .replaceAll('{pinId}', pinId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Get pin likes
  ///
  /// Get pin likes
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  Future<PinLikeDto?> getPinLikes(String pinId,) async {
    final response = await getPinLikesWithHttpInfo(pinId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PinLikeDto',) as PinLikeDto;
    
    }
    return null;
  }

  /// Get user's likes
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> getUserLikesWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/likes'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Get user's likes
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<UserLikesDto?> getUserLikes(String userId,) async {
    final response = await getUserLikesWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'UserLikesDto',) as UserLikesDto;
    
    }
    return null;
  }
}
