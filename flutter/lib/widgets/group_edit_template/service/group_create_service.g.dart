// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_create_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupCreateService)
final groupCreateServiceProvider = GroupCreateServiceProvider._();

final class GroupCreateServiceProvider
    extends $NotifierProvider<GroupCreateService, GroupCreateState> {
  GroupCreateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupCreateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupCreateServiceHash();

  @$internal
  @override
  GroupCreateService create() => GroupCreateService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupCreateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupCreateState>(value),
    );
  }
}

String _$groupCreateServiceHash() =>
    r'df6cf154192216d2368f44ccbb6e535c6c4382f2';

abstract class _$GroupCreateService extends $Notifier<GroupCreateState> {
  GroupCreateState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GroupCreateState, GroupCreateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupCreateState, GroupCreateState>,
              GroupCreateState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(createGroupProfileImage)
final createGroupProfileImageProvider = CreateGroupProfileImageProvider._();

final class CreateGroupProfileImageProvider
    extends $FunctionalProvider<Uint8List?, Uint8List?, Uint8List?>
    with $Provider<Uint8List?> {
  CreateGroupProfileImageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createGroupProfileImageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createGroupProfileImageHash();

  @$internal
  @override
  $ProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uint8List? create(Ref ref) {
    return createGroupProfileImage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uint8List? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uint8List?>(value),
    );
  }
}

String _$createGroupProfileImageHash() =>
    r'822f1e78afb6eae7561b85ab5ca2f287a646fc57';
