# openapi.api.ReportApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createReport**](ReportApi.md#createreport) | **POST** /api/v2/report | Report content


# **createReport**
> createReport(reportDto, idempotencyKey)

Report content

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ReportApi();
final reportDto = ReportDto(); // ReportDto |
final idempotencyKey = idempotencyKey_example; // String | Optional client-generated key; replaying it with a different report returns 409.

try {
    api_instance.createReport(reportDto, idempotencyKey);
} catch (e) {
    print('Exception when calling ReportApi->createReport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportDto** | [**ReportDto**](ReportDto.md)|  |
 **idempotencyKey** | **String**| Optional client-generated key; replaying it with a different report returns 409. | [optional]

### Return type

void (empty response body)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
