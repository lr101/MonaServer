// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LikeService)
final likeServiceProvider = LikeServiceFamily._();

final class LikeServiceProvider
    extends $AsyncNotifierProvider<LikeService, PinLikeDto> {
  LikeServiceProvider._({
    required LikeServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'likeServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$likeServiceHash();

  @override
  String toString() {
    return r'likeServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LikeService create() => LikeService();

  @override
  bool operator ==(Object other) {
    return other is LikeServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$likeServiceHash() => r'cb881a8da52296e3a465208c319ec9d1df46b57b';

final class LikeServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          LikeService,
          AsyncValue<PinLikeDto>,
          PinLikeDto,
          FutureOr<PinLikeDto>,
          String
        > {
  LikeServiceFamily._()
    : super(
        retry: null,
        name: r'likeServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LikeServiceProvider call(String pinId) =>
      LikeServiceProvider._(argument: pinId, from: this);

  @override
  String toString() => r'likeServiceProvider';
}

abstract class _$LikeService extends $AsyncNotifier<PinLikeDto> {
  late final _$args = ref.$arg as String;
  String get pinId => _$args;

  FutureOr<PinLikeDto> build(String pinId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PinLikeDto>, PinLikeDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PinLikeDto>, PinLikeDto>,
              AsyncValue<PinLikeDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
