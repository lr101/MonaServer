# openapi.api.LikesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createOrUpdateLike**](LikesApi.md#createorupdatelike) | **POST** /api/v2/pins/{pinId}/likes | Create or update a like
[**getPinLikes**](LikesApi.md#getpinlikes) | **GET** /api/v2/pins/{pinId}/likes | Get pin likes
[**getUserLikes**](LikesApi.md#getuserlikes) | **GET** /api/v2/users/{userId}/likes | Get user's likes


# **createOrUpdateLike**
> PinLikeDto createOrUpdateLike(pinId, createLikeDto)

Create or update a like

Create or update a like

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = LikesApi();
final pinId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final createLikeDto = CreateLikeDto(); // CreateLikeDto | 

try {
    final result = api_instance.createOrUpdateLike(pinId, createLikeDto);
    print(result);
} catch (e) {
    print('Exception when calling LikesApi->createOrUpdateLike: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinId** | **String**|  | 
 **createLikeDto** | [**CreateLikeDto**](CreateLikeDto.md)|  | 

### Return type

[**PinLikeDto**](PinLikeDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPinLikes**
> PinLikeDto getPinLikes(pinId)

Get pin likes

Get pin likes

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = LikesApi();
final pinId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final result = api_instance.getPinLikes(pinId);
    print(result);
} catch (e) {
    print('Exception when calling LikesApi->getPinLikes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **pinId** | **String**|  | 

### Return type

[**PinLikeDto**](PinLikeDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUserLikes**
> UserLikesDto getUserLikes(userId)

Get user's likes

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = LikesApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final result = api_instance.getUserLikes(userId);
    print(result);
} catch (e) {
    print('Exception when calling LikesApi->getUserLikes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**UserLikesDto**](UserLikesDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

