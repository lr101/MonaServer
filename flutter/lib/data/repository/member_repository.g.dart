// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memberRepository)
final memberRepositoryProvider = MemberRepositoryProvider._();

final class MemberRepositoryProvider
    extends
        $FunctionalProvider<
          IMemberRepository,
          IMemberRepository,
          IMemberRepository
        >
    with $Provider<IMemberRepository> {
  MemberRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberRepositoryHash();

  @$internal
  @override
  $ProviderElement<IMemberRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IMemberRepository create(Ref ref) {
    return memberRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IMemberRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IMemberRepository>(value),
    );
  }
}

String _$memberRepositoryHash() => r'dc4f7633b83bce85a4986eb0206c297987b0bd37';
