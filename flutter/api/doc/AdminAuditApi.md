# openapi.api.AdminAuditApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listAdminAudit**](AdminAuditApi.md#listadminaudit) | **GET** /api/v3/admin/audit | List administrative audit events


# **listAdminAudit**
> AdminAuditPageDto listAdminAudit(cursor, limit, targetUserId, action)

List administrative audit events

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminAuditApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.
final targetUserId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Restrict events to one target account.
final action = ; // AdminActionKind | Restrict events to one action.

try {
    final result = api_instance.listAdminAudit(cursor, limit, targetUserId, action);
    print(result);
} catch (e) {
    print('Exception when calling AdminAuditApi->listAdminAudit: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]
 **targetUserId** | **String**| Restrict events to one target account. | [optional] 
 **action** | [**AdminActionKind**](.md)| Restrict events to one action. | [optional] 

### Return type

[**AdminAuditPageDto**](AdminAuditPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

