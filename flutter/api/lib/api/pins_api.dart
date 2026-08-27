//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PinsApi {
  PinsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Sync all pins and groups based on last seen date
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] lastSeen:
  ///   Syncs created and deleted pins after this date
  Future<Response> callSyncWithHttpInfo({ DateTime? lastSeen, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/sync';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (lastSeen != null) {
      queryParams.addAll(_queryParams('', 'lastSeen', lastSeen));
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

  /// Sync all pins and groups based on last seen date
  ///
  /// Parameters:
  ///
  /// * [DateTime] lastSeen:
  ///   Syncs created and deleted pins after this date
  Future<SyncDto?> callSync({ DateTime? lastSeen, }) async {
    final response = await callSyncWithHttpInfo( lastSeen: lastSeen, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SyncDto',) as SyncDto;
    
    }
    return null;
  }

  /// Create a new pin
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PinRequestDto] pinRequestDto (required):
  Future<Response> createPinWithHttpInfo(PinRequestDto pinRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins';

    // ignore: prefer_final_locals
    Object? postBody = pinRequestDto;

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

  /// Create a new pin
  ///
  /// Parameters:
  ///
  /// * [PinRequestDto] pinRequestDto (required):
  Future<PinWithOptionalImageDto?> createPin(PinRequestDto pinRequestDto,) async {
    final response = await createPinWithHttpInfo(pinRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PinWithOptionalImageDto',) as PinWithOptionalImageDto;
    
    }
    return null;
  }

  /// Delete a pin by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  Future<Response> deletePinWithHttpInfo(String pinId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins/{pinId}'
      .replaceAll('{pinId}', pinId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Delete a pin by ID
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  Future<void> deletePin(String pinId,) async {
    final response = await deletePinWithHttpInfo(pinId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get pin information by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [bool] withImage:
  ///   Describes if the image of the pin should be returned too
  Future<Response> getPinWithHttpInfo(String pinId, { bool? withImage, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins/{pinId}'
      .replaceAll('{pinId}', pinId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (withImage != null) {
      queryParams.addAll(_queryParams('', 'withImage', withImage));
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

  /// Get pin information by ID
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [bool] withImage:
  ///   Describes if the image of the pin should be returned too
  Future<PinWithOptionalImageDto?> getPin(String pinId, { bool? withImage, }) async {
    final response = await getPinWithHttpInfo(pinId,  withImage: withImage, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PinWithOptionalImageDto',) as PinWithOptionalImageDto;
    
    }
    return null;
  }

  /// Get the image associated with a pin by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getPinImageWithHttpInfo(String pinId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins/{pinId}/image'
      .replaceAll('{pinId}', pinId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (redirect != null) {
      queryParams.addAll(_queryParams('', 'redirect', redirect));
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

  /// Get the image associated with a pin by ID
  ///
  /// Parameters:
  ///
  /// * [String] pinId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getPinImage(String pinId, { bool? redirect, }) async {
    final response = await getPinImageWithHttpInfo(pinId,  redirect: redirect, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'String',) as String;
    
    }
    return null;
  }

  /// Get images by IDs
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<String>] ids:
  ///   Comma-separated list of image IDs
  ///
  /// * [String] groupId:
  ///   Only pins of this group are returned
  ///
  /// * [String] userId:
  ///   Only pins of this user are returned
  ///
  /// * [bool] withImage:
  ///   Describes if the images of the pins should be returned too
  ///
  /// * [int] compression:
  ///   Compression level for images (optional)
  ///
  /// * [int] height:
  ///   Height for images (optional)
  ///
  /// * [int] page:
  ///   page number (can only be used when ids is not set). Sorted by creation date descending
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  ///
  /// * [DateTime] updatedAfter:
  ///   only include pins that have been updated after this date.If set all deleted pins after this time are returned.
  Future<Response> getPinImagesByIdsWithHttpInfo({ List<String>? ids, String? groupId, String? userId, bool? withImage, int? compression, int? height, int? page, int? size, DateTime? updatedAfter, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/pins';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (ids != null) {
      queryParams.addAll(_queryParams('multi', 'ids', ids));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'groupId', groupId));
    }
    if (userId != null) {
      queryParams.addAll(_queryParams('', 'userId', userId));
    }
    if (withImage != null) {
      queryParams.addAll(_queryParams('', 'withImage', withImage));
    }
    if (compression != null) {
      queryParams.addAll(_queryParams('', 'compression', compression));
    }
    if (height != null) {
      queryParams.addAll(_queryParams('', 'height', height));
    }
    if (page != null) {
      queryParams.addAll(_queryParams('', 'page', page));
    }
    if (size != null) {
      queryParams.addAll(_queryParams('', 'size', size));
    }
    if (updatedAfter != null) {
      queryParams.addAll(_queryParams('', 'updatedAfter', updatedAfter));
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

  /// Get images by IDs
  ///
  /// Parameters:
  ///
  /// * [List<String>] ids:
  ///   Comma-separated list of image IDs
  ///
  /// * [String] groupId:
  ///   Only pins of this group are returned
  ///
  /// * [String] userId:
  ///   Only pins of this user are returned
  ///
  /// * [bool] withImage:
  ///   Describes if the images of the pins should be returned too
  ///
  /// * [int] compression:
  ///   Compression level for images (optional)
  ///
  /// * [int] height:
  ///   Height for images (optional)
  ///
  /// * [int] page:
  ///   page number (can only be used when ids is not set). Sorted by creation date descending
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  ///
  /// * [DateTime] updatedAfter:
  ///   only include pins that have been updated after this date.If set all deleted pins after this time are returned.
  Future<PinsSyncDto?> getPinImagesByIds({ List<String>? ids, String? groupId, String? userId, bool? withImage, int? compression, int? height, int? page, int? size, DateTime? updatedAfter, }) async {
    final response = await getPinImagesByIdsWithHttpInfo( ids: ids, groupId: groupId, userId: userId, withImage: withImage, compression: compression, height: height, page: page, size: size, updatedAfter: updatedAfter, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PinsSyncDto',) as PinsSyncDto;
    
    }
    return null;
  }
}
