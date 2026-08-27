//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class MembersApi {
  MembersApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// leave group or delete group when the user is the last group member
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  ///   userId
  Future<Response> deleteMemberFromGroupWithHttpInfo(String groupId, String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/members'
      .replaceAll('{groupId}', groupId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));

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

  /// leave group or delete group when the user is the last group member
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  ///   userId
  Future<void> deleteMemberFromGroup(String groupId, String userId,) async {
    final response = await deleteMemberFromGroupWithHttpInfo(groupId, userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get members of a group by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> getGroupMembersWithHttpInfo(String groupId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/members'
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

  /// Get members of a group by ID
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<List<MemberResponseDto>?> getGroupMembers(String groupId,) async {
    final response = await getGroupMembersWithHttpInfo(groupId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<MemberResponseDto>') as List)
        .cast<MemberResponseDto>()
        .toList(growable: false);

    }
    return null;
  }

  /// Add a member to a group by ID
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  ///   id of user
  ///
  /// * [String] inviteUrl:
  ///   inviteUrl to authorize a user to join a private group
  Future<Response> joinGroupWithHttpInfo(String groupId, String userId, { String? inviteUrl, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/members'
      .replaceAll('{groupId}', groupId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));
    if (inviteUrl != null) {
      queryParams.addAll(_queryParams('', 'inviteUrl', inviteUrl));
    }

    const contentTypes = <String>[];


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

  /// Add a member to a group by ID
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [String] userId (required):
  ///   id of user
  ///
  /// * [String] inviteUrl:
  ///   inviteUrl to authorize a user to join a private group
  Future<GroupDto?> joinGroup(String groupId, String userId, { String? inviteUrl, }) async {
    final response = await joinGroupWithHttpInfo(groupId, userId,  inviteUrl: inviteUrl, );
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
