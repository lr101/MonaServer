// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MemberService)
final memberServiceProvider = MemberServiceFamily._();

final class MemberServiceProvider
    extends $StreamNotifierProvider<MemberService, List<MemberEntity>> {
  MemberServiceProvider._({
    required MemberServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberServiceHash();

  @override
  String toString() {
    return r'memberServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MemberService create() => MemberService();

  @override
  bool operator ==(Object other) {
    return other is MemberServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberServiceHash() => r'6c8b267c3534bfa6002daebff0f0004fcba59904';

final class MemberServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          MemberService,
          AsyncValue<List<MemberEntity>>,
          List<MemberEntity>,
          Stream<List<MemberEntity>>,
          String
        > {
  MemberServiceFamily._()
    : super(
        retry: null,
        name: r'memberServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MemberServiceProvider call(String groupId) =>
      MemberServiceProvider._(argument: groupId, from: this);

  @override
  String toString() => r'memberServiceProvider';
}

abstract class _$MemberService extends $StreamNotifier<List<MemberEntity>> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  Stream<List<MemberEntity>> build(String groupId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<MemberEntity>>, List<MemberEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MemberEntity>>, List<MemberEntity>>,
              AsyncValue<List<MemberEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
