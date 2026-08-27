# openapi.api.RankingApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getGeoJson**](RankingApi.md#getgeojson) | **GET** /api/v2/map/geojson | 
[**getMapInfo**](RankingApi.md#getmapinfo) | **GET** /api/v2/map | 
[**groupRanking**](RankingApi.md#groupranking) | **GET** /api/v2/ranking/group | 
[**searchRanking**](RankingApi.md#searchranking) | **GET** /api/v2/ranking/search | Search for a location
[**userRanking**](RankingApi.md#userranking) | **GET** /api/v2/ranking/user | 


# **getGeoJson**
> List<String> getGeoJson(gid2, gid1, gid0)



Gets the geojson info of a specific gid

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RankingApi();
final gid2 = gid2_example; // String | County ID. Only one allowed
final gid1 = gid1_example; // String | State ID. Only one allowed
final gid0 = gid0_example; // String | Country ID. Only one allowed

try {
    final result = api_instance.getGeoJson(gid2, gid1, gid0);
    print(result);
} catch (e) {
    print('Exception when calling RankingApi->getGeoJson: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gid2** | **String**| County ID. Only one allowed | [optional] 
 **gid1** | **String**| State ID. Only one allowed | [optional] 
 **gid0** | **String**| Country ID. Only one allowed | [optional] 

### Return type

**List<String>**

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMapInfo**
> List<MapInfoDto> getMapInfo(latitude, longitude)



### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RankingApi();
final latitude = 8.14; // num | Together with longitude an info dto of the position can be requested.
final longitude = 8.14; // num | Together with latitude an info dto of the position can be requested.

try {
    final result = api_instance.getMapInfo(latitude, longitude);
    print(result);
} catch (e) {
    print('Exception when calling RankingApi->getMapInfo: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **latitude** | **num**| Together with longitude an info dto of the position can be requested. | [optional] 
 **longitude** | **num**| Together with latitude an info dto of the position can be requested. | [optional] 

### Return type

[**List<MapInfoDto>**](MapInfoDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **groupRanking**
> List<GroupRankingDtoInner> groupRanking(gid0, gid1, gid2, since, season, page, size)



### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RankingApi();
final gid0 = gid0_example; // String | Country ID. When not null the ranking by country is returned.
final gid1 = gid1_example; // String | State ID. When not null the ranking by country is returned.
final gid2 = gid2_example; // String | County ID. When not null the ranking by country is returned.
final since = 2013-10-20T19:20:30+01:00; // DateTime | Only include pins added since this point in time. When null all pins are included
final season = true; // bool | Only include pins from this season. When null all pins are included
final page = 56; // int | page number
final size = 56; // int | page size. Defaults to 20

try {
    final result = api_instance.groupRanking(gid0, gid1, gid2, since, season, page, size);
    print(result);
} catch (e) {
    print('Exception when calling RankingApi->groupRanking: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gid0** | **String**| Country ID. When not null the ranking by country is returned. | [optional] 
 **gid1** | **String**| State ID. When not null the ranking by country is returned. | [optional] 
 **gid2** | **String**| County ID. When not null the ranking by country is returned. | [optional] 
 **since** | **DateTime**| Only include pins added since this point in time. When null all pins are included | [optional] 
 **season** | **bool**| Only include pins from this season. When null all pins are included | [optional] [default to false]
 **page** | **int**| page number | [optional] 
 **size** | **int**| page size. Defaults to 20 | [optional] [default to 20]

### Return type

[**List<GroupRankingDtoInner>**](GroupRankingDtoInner.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchRanking**
> List<RankingSearchDtoInner> searchRanking(search, page, size)

Search for a location

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = RankingApi();
final search = search_example; // String | 
final page = 56; // int | page number
final size = 56; // int | page size. Defaults to 20

try {
    final result = api_instance.searchRanking(search, page, size);
    print(result);
} catch (e) {
    print('Exception when calling RankingApi->searchRanking: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **search** | **String**|  | [optional] 
 **page** | **int**| page number | [optional] 
 **size** | **int**| page size. Defaults to 20 | [optional] [default to 20]

### Return type

[**List<RankingSearchDtoInner>**](RankingSearchDtoInner.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **userRanking**
> List<UserRankingDtoInner> userRanking(gid0, gid1, gid2, since, season, page, size)



### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = RankingApi();
final gid0 = gid0_example; // String | Country ID. When not null the ranking by country is returned.
final gid1 = gid1_example; // String | State ID. When not null the ranking by country is returned.
final gid2 = gid2_example; // String | County ID. When not null the ranking by country is returned.
final since = 2013-10-20T19:20:30+01:00; // DateTime | Only include pins added since this point in time. When null all pins are included
final season = true; // bool | Only include pins from this season. When null all pins are included
final page = 56; // int | page number
final size = 56; // int | page size. Defaults to 20

try {
    final result = api_instance.userRanking(gid0, gid1, gid2, since, season, page, size);
    print(result);
} catch (e) {
    print('Exception when calling RankingApi->userRanking: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **gid0** | **String**| Country ID. When not null the ranking by country is returned. | [optional] 
 **gid1** | **String**| State ID. When not null the ranking by country is returned. | [optional] 
 **gid2** | **String**| County ID. When not null the ranking by country is returned. | [optional] 
 **since** | **DateTime**| Only include pins added since this point in time. When null all pins are included | [optional] 
 **season** | **bool**| Only include pins from this season. When null all pins are included | [optional] [default to false]
 **page** | **int**| page number | [optional] 
 **size** | **int**| page size. Defaults to 20 | [optional] [default to 20]

### Return type

[**List<UserRankingDtoInner>**](UserRankingDtoInner.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

