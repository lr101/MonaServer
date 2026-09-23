# openapi.model.AdminAudienceFilter

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**createdAfter** | [**DateTime**](DateTime.md) |  | [optional]
**createdBefore** | [**DateTime**](DateTime.md) |  | [optional]
**email** | **String** |  | [optional]
**id** | **String** |  | [optional]
**includeAdmins** | **bool** |  | [optional] [default to false]
**resource** | **String** |  |
**securityStatuses** | [**List<AdminSecurityState>**](AdminSecurityState.md) |  | [optional] [default to const []]
**username** | **String** |  | [optional]
**verifiedEmail** | **bool** |  | [optional]
**assigneeUserId** | **String** |  | [optional]
**statuses** | [**List<AdminReportStatus>**](AdminReportStatus.md) |  | [optional] [default to const []]
**types** | **List<String>** |  | [optional] [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
