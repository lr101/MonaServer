# openapi.api.MembersApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteMemberFromGroup**](MembersApi.md#deletememberfromgroup) | **DELETE** /api/v2/groups/{groupId}/members | leave group or delete group when the user is the last group member
[**getGroupMembers**](MembersApi.md#getgroupmembers) | **GET** /api/v2/groups/{groupId}/members | Get members of a group by ID
[**joinGroup**](MembersApi.md#joingroup) | **POST** /api/v2/groups/{groupId}/members | Add a member to a group by ID


# **deleteMemberFromGroup**
> deleteMemberFromGroup(groupId, userId)

leave group or delete group when the user is the last group member

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = MembersApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | userId

try {
    api_instance.deleteMemberFromGroup(groupId, userId);
} catch (e) {
    print('Exception when calling MembersApi->deleteMemberFromGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 
 **userId** | **String**| userId | 

### Return type

void (empty response body)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupMembers**
> List<MemberResponseDto> getGroupMembers(groupId)

Get members of a group by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = MembersApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final result = api_instance.getGroupMembers(groupId);
    print(result);
} catch (e) {
    print('Exception when calling MembersApi->getGroupMembers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 

### Return type

[**List<MemberResponseDto>**](MemberResponseDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **joinGroup**
> GroupDto joinGroup(groupId, userId, inviteUrl)

Add a member to a group by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = MembersApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | id of user
final inviteUrl = inviteUrl_example; // String | inviteUrl to authorize a user to join a private group

try {
    final result = api_instance.joinGroup(groupId, userId, inviteUrl);
    print(result);
} catch (e) {
    print('Exception when calling MembersApi->joinGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 
 **userId** | **String**| id of user | 
 **inviteUrl** | **String**| inviteUrl to authorize a user to join a private group | [optional] 

### Return type

[**GroupDto**](GroupDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

