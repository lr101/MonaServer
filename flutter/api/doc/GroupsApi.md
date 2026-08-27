# openapi.api.GroupsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**addGroup**](GroupsApi.md#addgroup) | **POST** /api/v2/groups | Create a new group
[**deleteGroup**](GroupsApi.md#deletegroup) | **DELETE** /api/v2/groups/{groupId} | Delete a group by ID
[**getGroup**](GroupsApi.md#getgroup) | **GET** /api/v2/groups/{groupId} | Get a group by ID
[**getGroupAdmin**](GroupsApi.md#getgroupadmin) | **GET** /api/v2/groups/{groupId}/admin | Get admin of group
[**getGroupDescription**](GroupsApi.md#getgroupdescription) | **GET** /api/v2/groups/{groupId}/description | Get description of group
[**getGroupInviteUrl**](GroupsApi.md#getgroupinviteurl) | **GET** /api/v2/groups/{groupId}/invite_url | Get invite url of group
[**getGroupLink**](GroupsApi.md#getgrouplink) | **GET** /api/v2/groups/{groupId}/link | Get link of group
[**getGroupPinImage**](GroupsApi.md#getgrouppinimage) | **GET** /api/v2/groups/{groupId}/pin_image | Get pin image of group
[**getGroupProfileImage**](GroupsApi.md#getgroupprofileimage) | **GET** /api/v2/groups/{groupId}/profile_image | Get profile of group
[**getGroupProfileImageSmall**](GroupsApi.md#getgroupprofileimagesmall) | **GET** /api/v2/groups/{groupId}/profile_image_small | Get small profile image url of group
[**getGroupsByIds**](GroupsApi.md#getgroupsbyids) | **GET** /api/v2/groups | Get groups by IDs
[**updateGroup**](GroupsApi.md#updategroup) | **PUT** /api/v2/groups/{groupId} | Update a group by ID


# **addGroup**
> GroupDto addGroup(createGroupDto)

Create a new group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final createGroupDto = CreateGroupDto(); // CreateGroupDto | 

try {
    final result = api_instance.addGroup(createGroupDto);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->addGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createGroupDto** | [**CreateGroupDto**](CreateGroupDto.md)|  | 

### Return type

[**GroupDto**](GroupDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteGroup**
> deleteGroup(groupId)

Delete a group by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api_instance.deleteGroup(groupId);
} catch (e) {
    print('Exception when calling GroupsApi->deleteGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroup**
> GroupDto getGroup(groupId)

Get a group by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final result = api_instance.getGroup(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 

### Return type

[**GroupDto**](GroupDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupAdmin**
> String getGroupAdmin(groupId)

Get admin of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id

try {
    final result = api_instance.getGroupAdmin(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupAdmin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupDescription**
> String getGroupDescription(groupId)

Get description of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id

try {
    final result = api_instance.getGroupDescription(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupDescription: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupInviteUrl**
> String getGroupInviteUrl(groupId)

Get invite url of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id

try {
    final result = api_instance.getGroupInviteUrl(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupInviteUrl: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupLink**
> String getGroupLink(groupId)

Get link of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id

try {
    final result = api_instance.getGroupLink(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupLink: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupPinImage**
> String getGroupPinImage(groupId, redirect)

Get pin image of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id
final redirect = true; // bool | When true, this endpoint redirects directly to the target image otherwise the image URL is returned

try {
    final result = api_instance.getGroupPinImage(groupId, redirect);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupPinImage: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 
 **redirect** | **bool**| When true, this endpoint redirects directly to the target image otherwise the image URL is returned | [optional] [default to false]

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/png, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupProfileImage**
> String getGroupProfileImage(groupId, redirect)

Get profile of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id
final redirect = true; // bool | When true, this endpoint redirects directly to the target image otherwise the image URL is returned

try {
    final result = api_instance.getGroupProfileImage(groupId, redirect);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupProfileImage: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 
 **redirect** | **bool**| When true, this endpoint redirects directly to the target image otherwise the image URL is returned | [optional] [default to false]

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/*, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupProfileImageSmall**
> String getGroupProfileImageSmall(groupId, redirect)

Get small profile image url of group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | group id
final redirect = true; // bool | When true, this endpoint redirects directly to the target image otherwise the image URL is returned

try {
    final result = api_instance.getGroupProfileImageSmall(groupId, redirect);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupProfileImageSmall: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**| group id | 
 **redirect** | **bool**| When true, this endpoint redirects directly to the target image otherwise the image URL is returned | [optional] [default to false]

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/*, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getGroupsByIds**
> GroupsSyncDto getGroupsByIds(ids, search, userId, withUser, withImages, page, size, updatedAfter)

Get groups by IDs

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final ids = []; // List<String> | Comma-separated list of group IDs
final search = search_example; // String | search term used to find a group name
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | this is the userId used when withUser is set to true or false
final withUser = true; // bool | use false if user groups should be included and true if user groups should be excluded from search
final withImages = true; // bool | use false if profile picture should not be returned and true if it should. Defaults to false
final page = 56; // int | page number
final size = 56; // int | page size. Defaults to 20
final updatedAfter = 2013-10-20T19:20:30+01:00; // DateTime | only include groups that have been updated after this date. If set all deleted groups after this time are returned.

try {
    final result = api_instance.getGroupsByIds(ids, search, userId, withUser, withImages, page, size, updatedAfter);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->getGroupsByIds: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ids** | [**List<String>**](String.md)| Comma-separated list of group IDs | [optional] [default to const []]
 **search** | **String**| search term used to find a group name | [optional] 
 **userId** | **String**| this is the userId used when withUser is set to true or false | [optional] 
 **withUser** | **bool**| use false if user groups should be included and true if user groups should be excluded from search | [optional] 
 **withImages** | **bool**| use false if profile picture should not be returned and true if it should. Defaults to false | [optional] [default to false]
 **page** | **int**| page number | [optional] 
 **size** | **int**| page size. Defaults to 20 | [optional] [default to 20]
 **updatedAfter** | **DateTime**| only include groups that have been updated after this date. If set all deleted groups after this time are returned. | [optional] 

### Return type

[**GroupsSyncDto**](GroupsSyncDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateGroup**
> GroupDto updateGroup(groupId, updateGroupDto)

Update a group by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final updateGroupDto = UpdateGroupDto(); // UpdateGroupDto | 

try {
    final result = api_instance.updateGroup(groupId, updateGroupDto);
    print(result);
} catch (e) {
    print('Exception when calling GroupsApi->updateGroup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  | 
 **updateGroupDto** | [**UpdateGroupDto**](UpdateGroupDto.md)|  | 

### Return type

[**GroupDto**](GroupDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

