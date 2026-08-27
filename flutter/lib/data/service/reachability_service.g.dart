// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reachability_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reachabilityService)
final reachabilityServiceProvider = ReachabilityServiceProvider._();

final class ReachabilityServiceProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  ReachabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reachabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reachabilityServiceHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return reachabilityService(ref);
  }
}

String _$reachabilityServiceHash() =>
    r'cfd90fc1cee128f4572f2805b078f4805f02a07a';
