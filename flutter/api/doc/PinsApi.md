# openapi.api.PinsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**callSync**](PinsApi.md#callsync) | **GET** /api/v3/sync | Sync all pins and groups based on last seen date
[**createPin**](PinsApi.md#createpin) | **POST** /api/v2/pins | Create a new pin
[**deletePin**](PinsApi.md#deletepin) | **DELETE** /api/v2/pins/{pinId} | Delete a pin by ID
[**getPin**](PinsApi.md#getpin) | **GET** /api/v2/pins/{pinId} | Get pin information by ID
[**getPinImage**](PinsApi.md#getpinimage) | **GET** /api/v2/pins/{pinId}/image | Get the image associated with a pin by ID
[**getPinImagesByIds**](PinsApi.md#getpinimagesbyids) | **GET** /api/v2/pins | Get images by IDs


# **callSync**
> SyncDto callSync(lastSeen)

Sync all pins and groups based on last seen date

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final lastSeen = 2013-10-20T19:20:30+01:00; // DateTime | Syncs created and deleted pins after this date

try {
    final result = api_instance.callSync(lastSeen);
    print(result);
} catch (e) {
    print('Exception when calling PinsApi->callSync: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **lastSeen** | **DateTime**| Syncs created and deleted pins after this date | [optional] 

### Return type

[**SyncDto**](SyncDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createPin**
> PinWithOptionalImageDto createPin(pinRequestDto)

Create a new pin

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final pinRequestDto = PinRequestDto(); // PinRequestDto | 

try {
    final result = api_instance.createPin(pinRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling PinsApi->createPin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinRequestDto** | [**PinRequestDto**](PinRequestDto.md)|  | 

### Return type

[**PinWithOptionalImageDto**](PinWithOptionalImageDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deletePin**
> deletePin(pinId)

Delete a pin by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final pinId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api_instance.deletePin(pinId);
} catch (e) {
    print('Exception when calling PinsApi->deletePin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPin**
> PinWithOptionalImageDto getPin(pinId, withImage)

Get pin information by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final pinId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final withImage = true; // bool | Describes if the image of the pin should be returned too

try {
    final result = api_instance.getPin(pinId, withImage);
    print(result);
} catch (e) {
    print('Exception when calling PinsApi->getPin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinId** | **String**|  | 
 **withImage** | **bool**| Describes if the image of the pin should be returned too | [optional] [default to false]

### Return type

[**PinWithOptionalImageDto**](PinWithOptionalImageDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPinImage**
> String getPinImage(pinId, redirect)

Get the image associated with a pin by ID

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final pinId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final redirect = true; // bool | When true, this endpoint redirects directly to the target image otherwise the image URL is returned

try {
    final result = api_instance.getPinImage(pinId, redirect);
    print(result);
} catch (e) {
    print('Exception when calling PinsApi->getPinImage: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinId** | **String**|  | 
 **redirect** | **bool**| When true, this endpoint redirects directly to the target image otherwise the image URL is returned | [optional] [default to false]

### Return type

**String**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/*, text/plain; charset=utf-8

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPinImagesByIds**
> PinsSyncDto getPinImagesByIds(ids, groupId, userId, withImage, compression, height, page, size, updatedAfter)

Get images by IDs

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = PinsApi();
final ids = []; // List<String> | Comma-separated list of image IDs
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Only pins of this group are returned
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Only pins of this user are returned
final withImage = true; // bool | Describes if the images of the pins should be returned too
final compression = 56; // int | Compression level for images (optional)
final height = 56; // int | Height for images (optional)
final page = 56; // int | page number (can only be used when ids is not set). Sorted by creation date descending
final size = 56; // int | page size. Defaults to 20
final updatedAfter = 2013-10-20T19:20:30+01:00; // DateTime | only include pins that have been updated after this date.If set all deleted pins after this time are returned.

try {
    final result = api_instance.getPinImagesByIds(ids, groupId, userId, withImage, compression, height, page, size, updatedAfter);
    print(result);
} catch (e) {
    print('Exception when calling PinsApi->getPinImagesByIds: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **ids** | [**List<String>**](String.md)| Comma-separated list of image IDs | [optional] [default to const []]
 **groupId** | **String**| Only pins of this group are returned | [optional] 
 **userId** | **String**| Only pins of this user are returned | [optional] 
 **withImage** | **bool**| Describes if the images of the pins should be returned too | [optional] [default to false]
 **compression** | **int**| Compression level for images (optional) | [optional] 
 **height** | **int**| Height for images (optional) | [optional] 
 **page** | **int**| page number (can only be used when ids is not set). Sorted by creation date descending | [optional] 
 **size** | **int**| page size. Defaults to 20 | [optional] [default to 20]
 **updatedAfter** | **DateTime**| only include pins that have been updated after this date.If set all deleted pins after this time are returned. | [optional] 

### Return type

[**PinsSyncDto**](PinsSyncDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

