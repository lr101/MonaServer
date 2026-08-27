// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_edit_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserEditState)
final userEditStateProvider = UserEditStateProvider._();

final class UserEditStateProvider
    extends $NotifierProvider<UserEditState, Uint8List?> {
  UserEditStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userEditStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userEditStateHash();

  @$internal
  @override
  UserEditState create() => UserEditState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uint8List? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uint8List?>(value),
    );
  }
}

String _$userEditStateHash() => r'a36832e8d0a81592ade3d821a95f182ff03f5ba0';

abstract class _$UserEditState extends $Notifier<Uint8List?> {
  Uint8List? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Uint8List?, Uint8List?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Uint8List?, Uint8List?>,
              Uint8List?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
