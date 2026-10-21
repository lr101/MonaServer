//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GalleryApi {
  GalleryApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Discover visible original and update photos in stable observedAt/id descending order
  ///
  /// Exactly one of userId or groupId is required. User scope selects the contributor of each photograph. Cursor is opaque; use nextCursor until absent. Deleted pins and groups and inaccessible groups are excluded.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId:
  ///
  /// * [String] groupId:
  ///
  /// * [String] cursor:
  ///
  /// * [int] limit:
  Future<Response> getGalleryPhotosWithHttpInfo({
    String? userId,
    String? groupId,
    String? cursor,
    int? limit,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/gallery/photos';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (userId != null) {
      queryParams.addAll(_queryParams('', 'userId', userId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'groupId', groupId));
    }
    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
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

  /// Discover visible original and update photos in stable observedAt/id descending order
  ///
  /// Exactly one of userId or groupId is required. User scope selects the contributor of each photograph. Cursor is opaque; use nextCursor until absent. Deleted pins and groups and inaccessible groups are excluded.
  ///
  /// Parameters:
  ///
  /// * [String] userId:
  ///
  /// * [String] groupId:
  ///
  /// * [String] cursor:
  ///
  /// * [int] limit:
  Future<GalleryPhotoPageDto?> getGalleryPhotos({
    String? userId,
    String? groupId,
    String? cursor,
    int? limit,
  }) async {
    final response = await getGalleryPhotosWithHttpInfo(
      userId: userId,
      groupId: groupId,
      cursor: cursor,
      limit: limit,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'GalleryPhotoPageDto',
      ) as GalleryPhotoPageDto;
    }
    return null;
  }

  /// Resolve signed URLs for up to 100 photos with per-item authorization
  ///
  /// Items preserve request order. An inaccessible or missing photograph returns status 404 without metadata. Each successful item contains both URL variants.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PhotoResolveRequestDto] photoResolveRequestDto (required):
  Future<Response> resolvePhotosWithHttpInfo(
    PhotoResolveRequestDto photoResolveRequestDto,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/photos/resolve';

    // ignore: prefer_final_locals
    Object? postBody = photoResolveRequestDto;

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

  /// Resolve signed URLs for up to 100 photos with per-item authorization
  ///
  /// Items preserve request order. An inaccessible or missing photograph returns status 404 without metadata. Each successful item contains both URL variants.
  ///
  /// Parameters:
  ///
  /// * [PhotoResolveRequestDto] photoResolveRequestDto (required):
  Future<PhotoResolveResponseDto?> resolvePhotos(
    PhotoResolveRequestDto photoResolveRequestDto,
  ) async {
    final response = await resolvePhotosWithHttpInfo(
      photoResolveRequestDto,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'PhotoResolveResponseDto',
      ) as PhotoResolveResponseDto;
    }
    return null;
  }
}
