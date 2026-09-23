# openapi.api.AdminUsersApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminUser**](AdminUsersApi.md#getadminuser) | **GET** /api/v3/admin/users/{userId} | Get one administrative user record
[**listAdminUsers**](AdminUsersApi.md#listadminusers) | **GET** /api/v3/admin/users | Search administrative user records


# **getAdminUser**
> AdminUserDetailsDto getAdminUser(userId)

Get one administrative user record

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable account identifier.

try {
    final result = api_instance.getAdminUser(userId);
    print(result);
} catch (e) {
    print('Exception when calling AdminUsersApi->getAdminUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**| Stable account identifier. | 

### Return type

[**AdminUserDetailsDto**](AdminUserDetailsDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminUsers**
> AdminUserPageDto listAdminUsers(cursor, limit, search, securityStatus, verifiedEmail, createdAfter, createdBefore)

Search administrative user records

Return bounded account records without tokens, password hashes, or other credential material.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.
final search = search_example; // String | Case-insensitive username, email, or stable ID search.
final securityStatus = ; // AdminSecurityState | Restrict results to one security state.
final verifiedEmail = true; // bool | Restrict results by verified-email presence.
final createdAfter = 2013-10-20T19:20:30+01:00; // DateTime | Include accounts created at or after this instant.
final createdBefore = 2013-10-20T19:20:30+01:00; // DateTime | Include accounts created before this instant.

try {
    final result = api_instance.listAdminUsers(cursor, limit, search, securityStatus, verifiedEmail, createdAfter, createdBefore);
    print(result);
} catch (e) {
    print('Exception when calling AdminUsersApi->listAdminUsers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]
 **search** | **String**| Case-insensitive username, email, or stable ID search. | [optional] 
 **securityStatus** | [**AdminSecurityState**](.md)| Restrict results to one security state. | [optional] 
 **verifiedEmail** | **bool**| Restrict results by verified-email presence. | [optional] 
 **createdAfter** | **DateTime**| Include accounts created at or after this instant. | [optional] 
 **createdBefore** | **DateTime**| Include accounts created before this instant. | [optional] 

### Return type

[**AdminUserPageDto**](AdminUserPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

