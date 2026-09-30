# openapi.model.AdminUserUpdateDto

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**communicationOptOut** | **bool** |  | [optional]
**adminPermissions** | **List<String>** | Replacement permission list for an existing active admin membership. Only superadmins may set it. The superadmin entry grants every current and future permission, and an empty list removes all permissions. | [optional]
**expectedAuthGeneration** | **int** | Auth generation from the displayed user details. Rejects edits based on stale security state. |
**email** | **String** |  | [optional]
**passwordDisabled** | **bool** |  | [optional]
**passwordResetRequired** | **bool** |  | [optional]
**pushOptedOut** | **bool** |  | [optional]
**securityState** | **String** |  | [optional]
**username** | **String** |  | [optional]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
