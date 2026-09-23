# openapi.api.AdminJobsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelAdminJob**](AdminJobsApi.md#canceladminjob) | **POST** /api/v3/admin/jobs/{jobId}/cancel | Cancel pending job work
[**createAdminJob**](AdminJobsApi.md#createadminjob) | **POST** /api/v3/admin/jobs | Commit an administrative action job
[**getAdminJob**](AdminJobsApi.md#getadminjob) | **GET** /api/v3/admin/jobs/{jobId} | Read an administrative job
[**listAdminJobRecipients**](AdminJobsApi.md#listadminjobrecipients) | **GET** /api/v3/admin/jobs/{jobId}/recipients | List job recipient outcomes
[**listAdminJobs**](AdminJobsApi.md#listadminjobs) | **GET** /api/v3/admin/jobs | List administrative action jobs
[**retryAdminJob**](AdminJobsApi.md#retryadminjob) | **POST** /api/v3/admin/jobs/{jobId}/retry | Retry eligible failed job work


# **cancelAdminJob**
> AdminJobAcceptedDto cancelAdminJob(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto)

Cancel pending job work

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Durable job identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final idempotencyKey = idempotencyKey_example; // String | Client-generated business key; reusing it with a different payload returns 409.
final adminJobCommandRequestDto = AdminJobCommandRequestDto(); // AdminJobCommandRequestDto | 

try {
    final result = api_instance.cancelAdminJob(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->cancelAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**| Durable job identifier. | 
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **idempotencyKey** | **String**| Client-generated business key; reusing it with a different payload returns 409. | 
 **adminJobCommandRequestDto** | [**AdminJobCommandRequestDto**](AdminJobCommandRequestDto.md)|  | 

### Return type

[**AdminJobAcceptedDto**](AdminJobAcceptedDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminJob**
> AdminJobAcceptedDto createAdminJob(xCSRFToken, idempotencyKey, adminJobCreateRequestDto)

Commit an administrative action job

Commit exactly one unexpired preview snapshot and action. The Idempotency-Key header is required.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final idempotencyKey = idempotencyKey_example; // String | Client-generated business key; reusing it with a different payload returns 409.
final adminJobCreateRequestDto = AdminJobCreateRequestDto(); // AdminJobCreateRequestDto | 

try {
    final result = api_instance.createAdminJob(xCSRFToken, idempotencyKey, adminJobCreateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->createAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **idempotencyKey** | **String**| Client-generated business key; reusing it with a different payload returns 409. | 
 **adminJobCreateRequestDto** | [**AdminJobCreateRequestDto**](AdminJobCreateRequestDto.md)|  | 

### Return type

[**AdminJobAcceptedDto**](AdminJobAcceptedDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminJob**
> AdminJobDto getAdminJob(jobId)

Read an administrative job

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Durable job identifier.

try {
    final result = api_instance.getAdminJob(jobId);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->getAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**| Durable job identifier. | 

### Return type

[**AdminJobDto**](AdminJobDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminJobRecipients**
> AdminJobRecipientPageDto listAdminJobRecipients(jobId, cursor, limit)

List job recipient outcomes

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Durable job identifier.
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.

try {
    final result = api_instance.listAdminJobRecipients(jobId, cursor, limit);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->listAdminJobRecipients: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**| Durable job identifier. | 
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]

### Return type

[**AdminJobRecipientPageDto**](AdminJobRecipientPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminJobs**
> AdminJobPageDto listAdminJobs(cursor, limit, status, action)

List administrative action jobs

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.
final status = ; // AdminJobStatus | Restrict jobs to a lifecycle state.
final action = ; // AdminActionKind | Restrict jobs to one action.

try {
    final result = api_instance.listAdminJobs(cursor, limit, status, action);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->listAdminJobs: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]
 **status** | [**AdminJobStatus**](.md)| Restrict jobs to a lifecycle state. | [optional] 
 **action** | [**AdminActionKind**](.md)| Restrict jobs to one action. | [optional] 

### Return type

[**AdminJobPageDto**](AdminJobPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **retryAdminJob**
> AdminJobAcceptedDto retryAdminJob(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto)

Retry eligible failed job work

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminJobsApi();
final jobId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Durable job identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final idempotencyKey = idempotencyKey_example; // String | Client-generated business key; reusing it with a different payload returns 409.
final adminJobCommandRequestDto = AdminJobCommandRequestDto(); // AdminJobCommandRequestDto | 

try {
    final result = api_instance.retryAdminJob(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminJobsApi->retryAdminJob: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **jobId** | **String**| Durable job identifier. | 
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **idempotencyKey** | **String**| Client-generated business key; reusing it with a different payload returns 409. | 
 **adminJobCommandRequestDto** | [**AdminJobCommandRequestDto**](AdminJobCommandRequestDto.md)|  | 

### Return type

[**AdminJobAcceptedDto**](AdminJobAcceptedDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

