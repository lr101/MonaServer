// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_edit_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupEditService)
final groupEditServiceProvider = GroupEditServiceProvider._();

final class GroupEditServiceProvider
    extends $NotifierProvider<GroupEditService, String> {
  GroupEditServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupEditServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupEditServiceHash();

  @$internal
  @override
  GroupEditService create() => GroupEditService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$groupEditServiceHash() => r'ecc44e6add72623f6a839ba9b50b6c6a50fec9ba';

abstract class _$GroupEditService extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
