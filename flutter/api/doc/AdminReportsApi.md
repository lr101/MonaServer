# openapi.api.AdminReportsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**addAdminReportNote**](AdminReportsApi.md#addadminreportnote) | **POST** /api/v3/admin/reports/{reportId}/notes | Add an administrative report note
[**getAdminReport**](AdminReportsApi.md#getadminreport) | **GET** /api/v3/admin/reports/{reportId} | Read one report and its notes
[**listAdminReports**](AdminReportsApi.md#listadminreports) | **GET** /api/v3/admin/reports | List reports for administrative review
[**updateAdminReport**](AdminReportsApi.md#updateadminreport) | **PATCH** /api/v3/admin/reports/{reportId} | Apply a revision-checked report transition


# **addAdminReportNote**
> AdminReportNoteDto addAdminReportNote(reportId, xCSRFToken, adminReportNoteRequestDto)

Add an administrative report note

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminReportsApi();
final reportId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Report identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminReportNoteRequestDto = AdminReportNoteRequestDto(); // AdminReportNoteRequestDto | 

try {
    final result = api_instance.addAdminReportNote(reportId, xCSRFToken, adminReportNoteRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminReportsApi->addAdminReportNote: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportId** | **String**| Report identifier. | 
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **adminReportNoteRequestDto** | [**AdminReportNoteRequestDto**](AdminReportNoteRequestDto.md)|  | 

### Return type

[**AdminReportNoteDto**](AdminReportNoteDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminReport**
> AdminReportDto getAdminReport(reportId, revision)

Read one report and its notes

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminReportsApi();
final reportId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Report identifier.
final revision = 789; // int | Optional revision requested by the client.

try {
    final result = api_instance.getAdminReport(reportId, revision);
    print(result);
} catch (e) {
    print('Exception when calling AdminReportsApi->getAdminReport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportId** | **String**| Report identifier. | 
 **revision** | **int**| Optional revision requested by the client. | [optional] 

### Return type

[**AdminReportDto**](AdminReportDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminReports**
> AdminReportPageDto listAdminReports(cursor, limit, status, search)

List reports for administrative review

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminReportsApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.
final status = ; // AdminReportStatus | Restrict reports to one review state.
final search = search_example; // String | Search bounded report text or target identity.

try {
    final result = api_instance.listAdminReports(cursor, limit, status, search);
    print(result);
} catch (e) {
    print('Exception when calling AdminReportsApi->listAdminReports: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional] 
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]
 **status** | [**AdminReportStatus**](.md)| Restrict reports to one review state. | [optional] 
 **search** | **String**| Search bounded report text or target identity. | [optional] 

### Return type

[**AdminReportPageDto**](AdminReportPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateAdminReport**
> AdminReportDto updateAdminReport(reportId, xCSRFToken, adminReportUpdateRequestDto)

Apply a revision-checked report transition

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminReportsApi();
final reportId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Report identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminReportUpdateRequestDto = AdminReportUpdateRequestDto(); // AdminReportUpdateRequestDto | 

try {
    final result = api_instance.updateAdminReport(reportId, xCSRFToken, adminReportUpdateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminReportsApi->updateAdminReport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportId** | **String**| Report identifier. | 
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **adminReportUpdateRequestDto** | [**AdminReportUpdateRequestDto**](AdminReportUpdateRequestDto.md)|  | 

### Return type

[**AdminReportDto**](AdminReportDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

