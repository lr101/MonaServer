// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupService)
final groupServiceProvider = GroupServiceFamily._();

final class GroupServiceProvider
    extends $StreamNotifierProvider<GroupService, GroupEntity?> {
  GroupServiceProvider._({
    required GroupServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupServiceHash();

  @override
  String toString() {
    return r'groupServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupService create() => GroupService();

  @override
  bool operator ==(Object other) {
    return other is GroupServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupServiceHash() => r'8bcbb2936db5044f192ac13ea41f9d38bd5ba2e2';

final class GroupServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupService,
          AsyncValue<GroupEntity?>,
          GroupEntity?,
          Stream<GroupEntity?>,
          String
        > {
  GroupServiceFamily._()
    : super(
        retry: null,
        name: r'groupServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupServiceProvider call(String groupId) =>
      GroupServiceProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupServiceProvider';
}

abstract class _$GroupService extends $StreamNotifier<GroupEntity?> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  Stream<GroupEntity?> build(String groupId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<GroupEntity?>, GroupEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GroupEntity?>, GroupEntity?>,
              AsyncValue<GroupEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(UserGroupService)
final userGroupServiceProvider = UserGroupServiceProvider._();

final class UserGroupServiceProvider
    extends $StreamNotifierProvider<UserGroupService, List<GroupEntity>> {
  UserGroupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userGroupServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userGroupServiceHash();

  @$internal
  @override
  UserGroupService create() => UserGroupService();
}

String _$userGroupServiceHash() => r'ac8bd873fa8a7cf4ac441d5efca9c647f10116ca';

abstract class _$UserGroupService extends $StreamNotifier<List<GroupEntity>> {
  Stream<List<GroupEntity>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<GroupEntity>>, List<GroupEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<GroupEntity>>, List<GroupEntity>>,
              AsyncValue<List<GroupEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(activeGroups)
final activeGroupsProvider = ActiveGroupsProvider._();

final class ActiveGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<GroupEntity>>,
          Set<GroupEntity>,
          FutureOr<Set<GroupEntity>>
        >
    with $FutureModifier<Set<GroupEntity>>, $FutureProvider<Set<GroupEntity>> {
  ActiveGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeGroupsHash();

  @$internal
  @override
  $FutureProviderElement<Set<GroupEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<GroupEntity>> create(Ref ref) {
    return activeGroups(ref);
  }
}

String _$activeGroupsHash() => r'e5d7ef886f3600d64c19bca0f8fc43746086e078';

@ProviderFor(orderedGroups)
final orderedGroupsProvider = OrderedGroupsProvider._();

final class OrderedGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GroupEntity>>,
          List<GroupEntity>,
          FutureOr<List<GroupEntity>>
        >
    with
        $FutureModifier<List<GroupEntity>>,
        $FutureProvider<List<GroupEntity>> {
  OrderedGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderedGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderedGroupsHash();

  @$internal
  @override
  $FutureProviderElement<List<GroupEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GroupEntity>> create(Ref ref) {
    return orderedGroups(ref);
  }
}

String _$orderedGroupsHash() => r'90a66bed9252066fc88c4fd459f456d72505c7ed';

@ProviderFor(groupByIdActivated)
final groupByIdActivatedProvider = GroupByIdActivatedFamily._();

final class GroupByIdActivatedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  GroupByIdActivatedProvider._({
    required GroupByIdActivatedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupByIdActivatedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupByIdActivatedHash();

  @override
  String toString() {
    return r'groupByIdActivatedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return groupByIdActivated(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupByIdActivatedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupByIdActivatedHash() =>
    r'54a9a6471cfa0c997eed015d7c982a4e3934ac0a';

final class GroupByIdActivatedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  GroupByIdActivatedFamily._()
    : super(
        retry: null,
        name: r'groupByIdActivatedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupByIdActivatedProvider call(String groupId) =>
      GroupByIdActivatedProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupByIdActivatedProvider';
}
