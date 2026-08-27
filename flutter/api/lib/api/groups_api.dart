//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class GroupsApi {
  GroupsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create a new group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CreateGroupDto] createGroupDto (required):
  Future<Response> addGroupWithHttpInfo(CreateGroupDto createGroupDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups';

    // ignore: prefer_final_locals
    Object? postBody = createGroupDto;

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

  /// Create a new group
  ///
  /// Parameters:
  ///
  /// * [CreateGroupDto] createGroupDto (required):
  Future<GroupDto?> addGroup(CreateGroupDto createGroupDto,) async {
    final response = await addGroupWithHttpInfo(createGroupDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupDto',) as GroupDto;
    
    }
    return null;
  }

  /// Delete a group by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> deleteGroupWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}'
      .replaceAll('{groupId}', groupId);

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

  /// Delete a group by ID
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<void> deleteGroup(String groupId,) async {
    final response = await deleteGroupWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get a group by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> getGroupWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}'
      .replaceAll('{groupId}', groupId);

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

  /// Get a group by ID
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<GroupDto?> getGroup(String groupId,) async {
    final response = await getGroupWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupDto',) as GroupDto;
    
    }
    return null;
  }

  /// Get admin of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<Response> getGroupAdminWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/admin'
      .replaceAll('{groupId}', groupId);

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

  /// Get admin of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<String?> getGroupAdmin(String groupId,) async {
    final response = await getGroupAdminWithHttpInfo(groupId,);
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

  /// Get description of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<Response> getGroupDescriptionWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/description'
      .replaceAll('{groupId}', groupId);

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

  /// Get description of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<String?> getGroupDescription(String groupId,) async {
    final response = await getGroupDescriptionWithHttpInfo(groupId,);
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

  /// Get invite url of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<Response> getGroupInviteUrlWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/invite_url'
      .replaceAll('{groupId}', groupId);

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

  /// Get invite url of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<String?> getGroupInviteUrl(String groupId,) async {
    final response = await getGroupInviteUrlWithHttpInfo(groupId,);
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

  /// Get link of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<Response> getGroupLinkWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/link'
      .replaceAll('{groupId}', groupId);

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

  /// Get link of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  Future<String?> getGroupLink(String groupId,) async {
    final response = await getGroupLinkWithHttpInfo(groupId,);
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

  /// Get pin image of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getGroupPinImageWithHttpInfo(String groupId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/pin_image'
      .replaceAll('{groupId}', groupId);

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

  /// Get pin image of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getGroupPinImage(String groupId, { bool? redirect, }) async {
    final response = await getGroupPinImageWithHttpInfo(groupId,  redirect: redirect, );
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

  /// Get profile of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getGroupProfileImageWithHttpInfo(String groupId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/profile_image'
      .replaceAll('{groupId}', groupId);

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

  /// Get profile of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getGroupProfileImage(String groupId, { bool? redirect, }) async {
    final response = await getGroupProfileImageWithHttpInfo(groupId,  redirect: redirect, );
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

  /// Get small profile image url of group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getGroupProfileImageSmallWithHttpInfo(String groupId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/profile_image_small'
      .replaceAll('{groupId}', groupId);

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

  /// Get small profile image url of group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///   group id
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getGroupProfileImageSmall(String groupId, { bool? redirect, }) async {
    final response = await getGroupProfileImageSmallWithHttpInfo(groupId,  redirect: redirect, );
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

  /// Get groups by IDs
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<String>] ids:
  ///   Comma-separated list of group IDs
  ///
  /// * [String] search:
  ///   search term used to find a group name
  ///
  /// * [String] userId:
  ///   this is the userId used when withUser is set to true or false
  ///
  /// * [bool] withUser:
  ///   use false if user groups should be included and true if user groups should be excluded from search
  ///
  /// * [bool] withImages:
  ///   use false if profile picture should not be returned and true if it should. Defaults to false
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  ///
  /// * [DateTime] updatedAfter:
  ///   only include groups that have been updated after this date. If set all deleted groups after this time are returned.
  Future<Response> getGroupsByIdsWithHttpInfo({ List<String>? ids, String? search, String? userId, bool? withUser, bool? withImages, int? page, int? size, DateTime? updatedAfter, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (ids != null) {
      queryParams.addAll(_queryParams('multi', 'ids', ids));
    }
    if (search != null) {
      queryParams.addAll(_queryParams('', 'search', search));
    }
    if (userId != null) {
      queryParams.addAll(_queryParams('', 'userId', userId));
    }
    if (withUser != null) {
      queryParams.addAll(_queryParams('', 'withUser', withUser));
    }
    if (withImages != null) {
      queryParams.addAll(_queryParams('', 'withImages', withImages));
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

  /// Get groups by IDs
  ///
  /// Parameters:
  ///
  /// * [List<String>] ids:
  ///   Comma-separated list of group IDs
  ///
  /// * [String] search:
  ///   search term used to find a group name
  ///
  /// * [String] userId:
  ///   this is the userId used when withUser is set to true or false
  ///
  /// * [bool] withUser:
  ///   use false if user groups should be included and true if user groups should be excluded from search
  ///
  /// * [bool] withImages:
  ///   use false if profile picture should not be returned and true if it should. Defaults to false
  ///
  /// * [int] page:
  ///   page number
  ///
  /// * [int] size:
  ///   page size. Defaults to 20
  ///
  /// * [DateTime] updatedAfter:
  ///   only include groups that have been updated after this date. If set all deleted groups after this time are returned.
  Future<GroupsSyncDto?> getGroupsByIds({ List<String>? ids, String? search, String? userId, bool? withUser, bool? withImages, int? page, int? size, DateTime? updatedAfter, }) async {
    final response = await getGroupsByIdsWithHttpInfo( ids: ids, search: search, userId: userId, withUser: withUser, withImages: withImages, page: page, size: size, updatedAfter: updatedAfter, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupsSyncDto',) as GroupsSyncDto;
    
    }
    return null;
  }

  /// Update a group by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [UpdateGroupDto] updateGroupDto (required):
  Future<Response> updateGroupWithHttpInfo(String groupId, UpdateGroupDto updateGroupDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}'
      .replaceAll('{groupId}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = updateGroupDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update a group by ID
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [UpdateGroupDto] updateGroupDto (required):
  Future<GroupDto?> updateGroup(String groupId, UpdateGroupDto updateGroupDto,) async {
    final response = await updateGroupWithHttpInfo(groupId, updateGroupDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'GroupDto',) as GroupDto;
    
    }
    return null;
  }
}
