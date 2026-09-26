//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApiClient {
  ApiClient({this.basePath = 'https://stick-it.lr-projects.de', this.authentication,});

  final String basePath;
  final Authentication? authentication;

  var _client = Client();
  final _defaultHeaderMap = <String, String>{};

  /// Returns the current HTTP [Client] instance to use in this class.
  ///
  /// The return value is guaranteed to never be null.
  Client get client => _client;

  /// Requests to use a new HTTP [Client] in this class.
  set client(Client newClient) {
    _client = newClient;
  }

  Map<String, String> get defaultHeaderMap => _defaultHeaderMap;

  void addDefaultHeader(String key, String value) {
     _defaultHeaderMap[key] = value;
  }

  // We don't use a Map<String, String> for queryParams.
  // If collectionFormat is 'multi', a key might appear multiple times.
  Future<Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType,
  ) async {
    await authentication?.applyToParams(queryParams, headerParams);

    headerParams.addAll(_defaultHeaderMap);
    if (contentType != null) {
      headerParams['Content-Type'] = contentType;
    }

    final urlEncodedQueryParams = queryParams.map((param) => '$param');
    final queryString = urlEncodedQueryParams.isNotEmpty ? '?${urlEncodedQueryParams.join('&')}' : '';
    final uri = Uri.parse('$basePath$path$queryString');

    try {
      // Special case for uploading a single file which isn't a 'multipart/form-data'.
      if (
        body is MultipartFile && (contentType == null ||
        !contentType.toLowerCase().startsWith('multipart/form-data'))
      ) {
        final request = StreamedRequest(method, uri);
        request.headers.addAll(headerParams);
        request.contentLength = body.length;
        body.finalize().listen(
          request.sink.add,
          onDone: request.sink.close,
          // ignore: avoid_types_on_closure_parameters
          onError: (Object error, StackTrace trace) => request.sink.close(),
          cancelOnError: true,
        );
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      if (body is MultipartRequest) {
        final request = MultipartRequest(method, uri);
        request.fields.addAll(body.fields);
        request.files.addAll(body.files);
        request.headers.addAll(body.headers);
        request.headers.addAll(headerParams);
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      final msgBody = contentType == 'application/x-www-form-urlencoded'
        ? formParams
        : await serializeAsync(body);
      final nullableHeaderParams = headerParams.isEmpty ? null : headerParams;

      switch(method) {
        case 'POST': return await _client.post(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'PUT': return await _client.put(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'DELETE': return await _client.delete(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'PATCH': return await _client.patch(uri, headers: nullableHeaderParams, body: msgBody,);
        case 'HEAD': return await _client.head(uri, headers: nullableHeaderParams,);
        case 'GET': return await _client.get(uri, headers: nullableHeaderParams,);
      }
    } on SocketException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Socket operation failed: $method $path',
        error,
        trace,
      );
    } on TlsException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'TLS/SSL communication failed: $method $path',
        error,
        trace,
      );
    } on IOException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'I/O operation failed: $method $path',
        error,
        trace,
      );
    } on ClientException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'HTTP connection failed: $method $path',
        error,
        trace,
      );
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Exception occurred: $method $path',
        error,
        trace,
      );
    }

    throw ApiException(
      HttpStatus.badRequest,
      'Invalid HTTP operation: $method $path',
    );
  }

  Future<dynamic> deserializeAsync(String value, String targetType, {bool growable = false,}) async =>
    // ignore: deprecated_member_use_from_same_package
    deserialize(value, targetType, growable: growable);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use deserializeAsync() instead.')
  dynamic deserialize(String value, String targetType, {bool growable = false,}) {
    // Remove all spaces. Necessary for regular expressions as well.
    targetType = targetType.replaceAll(' ', ''); // ignore: parameter_assignments

    // If the expected target type is String, nothing to do...
    return targetType == 'String'
      ? value
      : fromJson(json.decode(value), targetType, growable: growable);
  }

  // ignore: deprecated_member_use_from_same_package
  Future<String> serializeAsync(Object? value) async => serialize(value);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use serializeAsync() instead.')
  String serialize(Object? value) => value == null ? '' : json.encode(value);

  /// Returns a native instance of an OpenAPI class matching the [specified type][targetType].
  static dynamic fromJson(dynamic value, String targetType, {bool growable = false,}) {
    try {
      switch (targetType) {
        case 'String':
          return value is String ? value : value.toString();
        case 'int':
          return value is int ? value : int.parse('$value');
        case 'double':
          return value is double ? value : double.parse('$value');
        case 'bool':
          if (value is bool) {
            return value;
          }
          final valueString = '$value'.toLowerCase();
          return valueString == 'true' || valueString == '1';
        case 'DateTime':
          return value is DateTime ? value : DateTime.tryParse(value);
        case 'AdminAction':
          return AdminAction.fromJson(value);
        case 'AdminActionKind':
          return AdminActionKindTypeTransformer().decode(value);
        case 'AdminAudience':
          return AdminAudience.fromJson(value);
        case 'AdminAudienceCountsDto':
          return AdminAudienceCountsDto.fromJson(value);
        case 'AdminAudienceExclusionDto':
          return AdminAudienceExclusionDto.fromJson(value);
        case 'AdminAudienceFilter':
          return AdminAudienceFilter.fromJson(value);
        case 'AdminAudienceMemberDto':
          return AdminAudienceMemberDto.fromJson(value);
        case 'AdminAudiencePageDto':
          return AdminAudiencePageDto.fromJson(value);
        case 'AdminAudiencePreviewAcceptedDto':
          return AdminAudiencePreviewAcceptedDto.fromJson(value);
        case 'AdminAudiencePreviewDto':
          return AdminAudiencePreviewDto.fromJson(value);
        case 'AdminAudiencePreviewRequestDto':
          return AdminAudiencePreviewRequestDto.fromJson(value);
        case 'AdminAudiencePreviewResponseDto':
          return AdminAudiencePreviewResponseDto.fromJson(value);
        case 'AdminAuditEventDto':
          return AdminAuditEventDto.fromJson(value);
        case 'AdminAuditPageDto':
          return AdminAuditPageDto.fromJson(value);
        case 'AdminCampaignChannel':
          return AdminCampaignChannelTypeTransformer().decode(value);
        case 'AdminCampaignContentDto':
          return AdminCampaignContentDto.fromJson(value);
        case 'AdminCampaignCreateRequestDto':
          return AdminCampaignCreateRequestDto.fromJson(value);
        case 'AdminCampaignDto':
          return AdminCampaignDto.fromJson(value);
        case 'AdminCampaignPageDto':
          return AdminCampaignPageDto.fromJson(value);
        case 'AdminCampaignRevisionRequestDto':
          return AdminCampaignRevisionRequestDto.fromJson(value);
        case 'AdminCampaignStatus':
          return AdminCampaignStatusTypeTransformer().decode(value);
        case 'AdminCampaignUpdateRequestDto':
          return AdminCampaignUpdateRequestDto.fromJson(value);
        case 'AdminJobAcceptedDto':
          return AdminJobAcceptedDto.fromJson(value);
        case 'AdminJobCommandRequestDto':
          return AdminJobCommandRequestDto.fromJson(value);
        case 'AdminJobCreateRequestDto':
          return AdminJobCreateRequestDto.fromJson(value);
        case 'AdminJobDto':
          return AdminJobDto.fromJson(value);
        case 'AdminJobPageDto':
          return AdminJobPageDto.fromJson(value);
        case 'AdminJobRecipientDto':
          return AdminJobRecipientDto.fromJson(value);
        case 'AdminJobRecipientPageDto':
          return AdminJobRecipientPageDto.fromJson(value);
        case 'AdminJobStatus':
          return AdminJobStatusTypeTransformer().decode(value);
        case 'AdminLoginLinkCampaignRequestDto':
          return AdminLoginLinkCampaignRequestDto.fromJson(value);
        case 'AdminMailDto':
          return AdminMailDto.fromJson(value);
        case 'AdminMfaRequestDto':
          return AdminMfaRequestDto.fromJson(value);
        case 'AdminReauthenticateRequestDto':
          return AdminReauthenticateRequestDto.fromJson(value);
        case 'AdminReportDto':
          return AdminReportDto.fromJson(value);
        case 'AdminReportFilterDto':
          return AdminReportFilterDto.fromJson(value);
        case 'AdminReportNoteDto':
          return AdminReportNoteDto.fromJson(value);
        case 'AdminReportNotePageDto':
          return AdminReportNotePageDto.fromJson(value);
        case 'AdminReportNoteRequestDto':
          return AdminReportNoteRequestDto.fromJson(value);
        case 'AdminReportPageDto':
          return AdminReportPageDto.fromJson(value);
        case 'AdminReportStatus':
          return AdminReportStatusTypeTransformer().decode(value);
        case 'AdminReportTargetDto':
          return AdminReportTargetDto.fromJson(value);
        case 'AdminReportUpdateRequestDto':
          return AdminReportUpdateRequestDto.fromJson(value);
        case 'AdminSecurityState':
          return AdminSecurityStateTypeTransformer().decode(value);
        case 'AdminSessionBootstrapDto':
          return AdminSessionBootstrapDto.fromJson(value);
        case 'AdminSessionDto':
          return AdminSessionDto.fromJson(value);
        case 'AdminSessionLoginRequestDto':
          return AdminSessionLoginRequestDto.fromJson(value);
        case 'AdminSessionLoginResponseDto':
          return AdminSessionLoginResponseDto.fromJson(value);
        case 'AdminSessionState':
          return AdminSessionStateTypeTransformer().decode(value);
        case 'AdminTestMessageAcceptedDto':
          return AdminTestMessageAcceptedDto.fromJson(value);
        case 'AdminTestMessageRequestDto':
          return AdminTestMessageRequestDto.fromJson(value);
        case 'AdminUserDetailsDto':
          return AdminUserDetailsDto.fromJson(value);
        case 'AdminUserDto':
          return AdminUserDto.fromJson(value);
        case 'AdminUserFilterDto':
          return AdminUserFilterDto.fromJson(value);
        case 'AdminUserPageDto':
          return AdminUserPageDto.fromJson(value);
        case 'AllAudience':
          return AllAudience.fromJson(value);
        case 'ApiErrorDto':
          return ApiErrorDto.fromJson(value);
        case 'AudienceKind':
          return AudienceKindTypeTransformer().decode(value);
        case 'AudienceResourceKind':
          return AudienceResourceKindTypeTransformer().decode(value);
        case 'BatchReadItem':
          return BatchReadItem.fromJson(value);
        case 'BatchReadRequest':
          return BatchReadRequest.fromJson(value);
        case 'BatchReadResponse':
          return BatchReadResponse.fromJson(value);
        case 'BatchReadResult':
          return BatchReadResult.fromJson(value);
        case 'CreateGroupDto':
          return CreateGroupDto.fromJson(value);
        case 'CreateLikeDto':
          return CreateLikeDto.fromJson(value);
        case 'EmailActionDto':
          return EmailActionDto.fromJson(value);
        case 'EmailLinkExchangeRequestDto':
          return EmailLinkExchangeRequestDto.fromJson(value);
        case 'EmailLinkExchangeResponseDto':
          return EmailLinkExchangeResponseDto.fromJson(value);
        case 'EmailLinkRequestAcceptedDto':
          return EmailLinkRequestAcceptedDto.fromJson(value);
        case 'EmailLinkRequestDto':
          return EmailLinkRequestDto.fromJson(value);
        case 'FilterAudience':
          return FilterAudience.fromJson(value);
        case 'GroupAchievementsDtoInner':
          return GroupAchievementsDtoInner.fromJson(value);
        case 'GroupDto':
          return GroupDto.fromJson(value);
        case 'GroupPinDesignBadge':
          return GroupPinDesignBadgeTypeTransformer().decode(value);
        case 'GroupPinDesignCatalogDto':
          return GroupPinDesignCatalogDto.fromJson(value);
        case 'GroupPinDesignDto':
          return GroupPinDesignDto.fromJson(value);
        case 'GroupPinDesignShape':
          return GroupPinDesignShapeTypeTransformer().decode(value);
        case 'GroupPinDesignStyle':
          return GroupPinDesignStyleTypeTransformer().decode(value);
        case 'GroupProgressionDto':
          return GroupProgressionDto.fromJson(value);
        case 'GroupRankingDtoInner':
          return GroupRankingDtoInner.fromJson(value);
        case 'GroupsSyncDto':
          return GroupsSyncDto.fromJson(value);
        case 'InfoDto':
          return InfoDto.fromJson(value);
        case 'LoginLinkActionDto':
          return LoginLinkActionDto.fromJson(value);
        case 'MapInfoDto':
          return MapInfoDto.fromJson(value);
        case 'MarkCompromisedActionDto':
          return MarkCompromisedActionDto.fromJson(value);
        case 'MemberResponseDto':
          return MemberResponseDto.fromJson(value);
        case 'NearbyPinDto':
          return NearbyPinDto.fromJson(value);
        case 'NearbyPinsDto':
          return NearbyPinsDto.fromJson(value);
        case 'NotificationDto':
          return NotificationDto.fromJson(value);
        case 'PinLikeDto':
          return PinLikeDto.fromJson(value);
        case 'PinPhotoDto':
          return PinPhotoDto.fromJson(value);
        case 'PinPhotoRequestDto':
          return PinPhotoRequestDto.fromJson(value);
        case 'PinPresenceRequestDto':
          return PinPresenceRequestDto.fromJson(value);
        case 'PinRequestDto':
          return PinRequestDto.fromJson(value);
        case 'PinWithOptionalImageDto':
          return PinWithOptionalImageDto.fromJson(value);
        case 'PinsSyncDto':
          return PinsSyncDto.fromJson(value);
        case 'PushActionDto':
          return PushActionDto.fromJson(value);
        case 'RankingSearchDtoInner':
          return RankingSearchDtoInner.fromJson(value);
        case 'RecoveryCompleteRequestDto':
          return RecoveryCompleteRequestDto.fromJson(value);
        case 'RecoveryResendActionDto':
          return RecoveryResendActionDto.fromJson(value);
        case 'RefreshTokenRequestDto':
          return RefreshTokenRequestDto.fromJson(value);
        case 'ReportDismissActionDto':
          return ReportDismissActionDto.fromJson(value);
        case 'ReportDto':
          return ReportDto.fromJson(value);
        case 'ReportResolveActionDto':
          return ReportResolveActionDto.fromJson(value);
        case 'RevokeSessionsActionDto':
          return RevokeSessionsActionDto.fromJson(value);
        case 'SeasonDto':
          return SeasonDto.fromJson(value);
        case 'SeasonItemDto':
          return SeasonItemDto.fromJson(value);
        case 'SelectedAudience':
          return SelectedAudience.fromJson(value);
        case 'SessionRevokeRequestDto':
          return SessionRevokeRequestDto.fromJson(value);
        case 'Status':
          return Status.fromJson(value);
        case 'SyncDto':
          return SyncDto.fromJson(value);
        case 'SyncDtoGroupUpdatesInner':
          return SyncDtoGroupUpdatesInner.fromJson(value);
        case 'TokenResponseDto':
          return TokenResponseDto.fromJson(value);
        case 'UpdateGroupDto':
          return UpdateGroupDto.fromJson(value);
        case 'UpdateGroupPinDesignCatalogDto':
          return UpdateGroupPinDesignCatalogDto.fromJson(value);
        case 'UserAchievementsDtoInner':
          return UserAchievementsDtoInner.fromJson(value);
        case 'UserInfoDto':
          return UserInfoDto.fromJson(value);
        case 'UserLikesDto':
          return UserLikesDto.fromJson(value);
        case 'UserLoginRequest':
          return UserLoginRequest.fromJson(value);
        case 'UserRankingDtoInner':
          return UserRankingDtoInner.fromJson(value);
        case 'UserRequestDto':
          return UserRequestDto.fromJson(value);
        case 'UserUpdateDto':
          return UserUpdateDto.fromJson(value);
        case 'UserUpdateResponseDto':
          return UserUpdateResponseDto.fromJson(value);
        case 'UserXpDto':
          return UserXpDto.fromJson(value);
        default:
          dynamic match;
          if (value is List && (match = _regList.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toList(growable: growable);
          }
          if (value is Set && (match = _regSet.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toSet();
          }
          if (value is Map && (match = _regMap.firstMatch(targetType)?.group(1)) != null) {
            return Map<String, dynamic>.fromIterables(
              value.keys.cast<String>(),
              value.values.map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,)),
            );
          }
      }
    } on Exception catch (error, trace) {
      throw ApiException.withInner(HttpStatus.internalServerError, 'Exception during deserialization.', error, trace,);
    }
    throw ApiException(HttpStatus.internalServerError, 'Could not find a suitable class for deserialization',);
  }
}

/// Primarily intended for use in an isolate.
class DeserializationMessage {
  const DeserializationMessage({
    required this.json,
    required this.targetType,
    this.growable = false,
  });

  /// The JSON value to deserialize.
  final String json;

  /// Target type to deserialize to.
  final String targetType;

  /// Whether to make deserialized lists or maps growable.
  final bool growable;
}

/// Primarily intended for use in an isolate.
Future<dynamic> decodeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : json.decode(message.json);
}

/// Primarily intended for use in an isolate.
Future<dynamic> deserializeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : ApiClient.fromJson(
        json.decode(message.json),
        targetType,
        growable: message.growable,
      );
}

/// Primarily intended for use in an isolate.
Future<String> serializeAsync(Object? value) async => value == null ? '' : json.encode(value);
