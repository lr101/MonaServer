# openapi.model.AdminUserDetailsDto

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**authGeneration** | **int** |  |
**compromisedAt** | [**DateTime**](DateTime.md) |  | [optional]
**createdAt** | [**DateTime**](DateTime.md) |  |
**email** | **String** |  | [optional]
**emailVerified** | **bool** |  |
**eligibilityReasons** | **List<String>** |  | [default to const []]
**id** | **String** |  |
**isAdmin** | **bool** |  |
**passwordDisabled** | **bool** |  |
**passwordResetRequired** | **bool** |  |
**securityState** | [**AdminSecurityState**](AdminSecurityState.md) |  |
**username** | **String** |  |
**adminPermissions** | **List<String>** | Current admin permission list. Returned only to superadmins; superadmin grants every current and future permission. | [optional] [default to const []]
**accountActivated** | **bool** |  |
**communicationOptOut** | **bool** |  |
**pushOptedOut** | **bool** |  |
**registeredDeviceCount** | **int** |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
