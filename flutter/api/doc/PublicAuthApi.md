# openapi.api.PublicAuthApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**completeRecovery**](PublicAuthApi.md#completerecovery) | **POST** /api/v3/public/auth/recovery/complete | Complete restricted account recovery
[**exchangeEmailLink**](PublicAuthApi.md#exchangeemaillink) | **POST** /api/v3/public/auth/email-link/exchange | Exchange a one-time email sign-in link
[**exchangeEmailLoginCode**](PublicAuthApi.md#exchangeemaillogincode) | **POST** /api/v3/public/auth/email-code/exchange | Exchange a one-time email sign-in code
[**requestEmailLink**](PublicAuthApi.md#requestemaillink) | **POST** /api/v3/public/auth/email-link/request | Request a one-time email sign-in link


# **completeRecovery**
> completeRecovery(recoveryCompleteRequestDto)

Complete restricted account recovery

Complete restricted password recovery with a purpose-limited action token.

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = PublicAuthApi();
final recoveryCompleteRequestDto = RecoveryCompleteRequestDto(); // RecoveryCompleteRequestDto |

try {
    api_instance.completeRecovery(recoveryCompleteRequestDto);
} catch (e) {
    print('Exception when calling PublicAuthApi->completeRecovery: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **recoveryCompleteRequestDto** | [**RecoveryCompleteRequestDto**](RecoveryCompleteRequestDto.md)|  |

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exchangeEmailLink**
> EmailLinkExchangeResponseDto exchangeEmailLink(emailLinkExchangeRequestDto)

Exchange a one-time email sign-in link

Exchange an opaque link only through POST; opening or scanning a link does not consume it.

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = PublicAuthApi();
final emailLinkExchangeRequestDto = EmailLinkExchangeRequestDto(); // EmailLinkExchangeRequestDto |

try {
    final result = api_instance.exchangeEmailLink(emailLinkExchangeRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling PublicAuthApi->exchangeEmailLink: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **emailLinkExchangeRequestDto** | [**EmailLinkExchangeRequestDto**](EmailLinkExchangeRequestDto.md)|  |

### Return type

[**EmailLinkExchangeResponseDto**](EmailLinkExchangeResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exchangeEmailLoginCode**
> EmailLinkExchangeResponseDto exchangeEmailLoginCode(emailLoginCodeExchangeRequestDto)

Exchange a one-time email sign-in code

Verify a six-character one-time email code and exchange it for the same credentials as the email sign-in link. Attempts are rate-limited and the code is bound to the submitted identifier.

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = PublicAuthApi();
final emailLoginCodeExchangeRequestDto = EmailLoginCodeExchangeRequestDto(); // EmailLoginCodeExchangeRequestDto |

try {
    final result = api_instance.exchangeEmailLoginCode(emailLoginCodeExchangeRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling PublicAuthApi->exchangeEmailLoginCode: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **emailLoginCodeExchangeRequestDto** | [**EmailLoginCodeExchangeRequestDto**](EmailLoginCodeExchangeRequestDto.md)|  |

### Return type

[**EmailLinkExchangeResponseDto**](EmailLinkExchangeResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestEmailLink**
> EmailLinkRequestAcceptedDto requestEmailLink(emailLinkRequestDto)

Request a one-time email sign-in link

Always returns the same accepted response for eligible and ineligible addresses.

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = PublicAuthApi();
final emailLinkRequestDto = EmailLinkRequestDto(); // EmailLinkRequestDto |

try {
    final result = api_instance.requestEmailLink(emailLinkRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling PublicAuthApi->requestEmailLink: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **emailLinkRequestDto** | [**EmailLinkRequestDto**](EmailLinkRequestDto.md)|  |

### Return type

[**EmailLinkRequestAcceptedDto**](EmailLinkRequestAcceptedDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

