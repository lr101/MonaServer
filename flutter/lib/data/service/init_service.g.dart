// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'init_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InitService)
final initServiceProvider = InitServiceProvider._();

final class InitServiceProvider
    extends $AsyncNotifierProvider<InitService, bool> {
  InitServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initServiceHash();

  @$internal
  @override
  InitService create() => InitService();
}

String _$initServiceHash() => r'c3354894ce07645d0cff0f2c51ad88cfa13f1346';

abstract class _$InitService extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
