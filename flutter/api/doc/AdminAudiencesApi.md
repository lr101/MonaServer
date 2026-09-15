# openapi.api.AdminAudiencesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminAudience**](AdminAudiencesApi.md#getadminaudience) | **GET** /api/v3/admin/audiences/{audienceId} | Read an administrative audience snapshot
[**previewAdminAudience**](AdminAudiencesApi.md#previewadminaudience) | **POST** /api/v3/admin/audiences/preview | Preview an explicit administrative audience


# **getAdminAudience**
> AdminAudiencePageDto getAdminAudience(audienceId, cursor, limit)

Read an administrative audience snapshot

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminAudiencesApi();
final audienceId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Immutable audience snapshot identifier.
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.

try {
    final result = api_instance.getAdminAudience(audienceId, cursor, limit);
    print(result);
} catch (e) {
    print('Exception when calling AdminAudiencesApi->getAdminAudience: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **audienceId** | **String**| Immutable audience snapshot identifier. | 
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]

### Return type

[**AdminAudiencePageDto**](AdminAudiencePageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewAdminAudience**
> AdminAudiencePreviewDto previewAdminAudience(xCSRFToken, adminAudiencePreviewRequestDto)

Preview an explicit administrative audience

Resolve an explicit account or report audience into an immutable actor/action/payload-bound snapshot.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminAudiencesApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminAudiencePreviewRequestDto = AdminAudiencePreviewRequestDto(); // AdminAudiencePreviewRequestDto | 

try {
    final result = api_instance.previewAdminAudience(xCSRFToken, adminAudiencePreviewRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminAudiencesApi->previewAdminAudience: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **adminAudiencePreviewRequestDto** | [**AdminAudiencePreviewRequestDto**](AdminAudiencePreviewRequestDto.md)|  | 

### Return type

[**AdminAudiencePreviewDto**](AdminAudiencePreviewDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

