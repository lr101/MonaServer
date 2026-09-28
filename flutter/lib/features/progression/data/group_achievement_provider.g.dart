// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_achievement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(groupAchievements)
final groupAchievementsProvider = GroupAchievementsFamily._();

final class GroupAchievementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GroupAchievementsDtoInner>?>,
          List<GroupAchievementsDtoInner>?,
          FutureOr<List<GroupAchievementsDtoInner>?>
        >
    with
        $FutureModifier<List<GroupAchievementsDtoInner>?>,
        $FutureProvider<List<GroupAchievementsDtoInner>?> {
  GroupAchievementsProvider._({
    required GroupAchievementsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupAchievementsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupAchievementsHash();

  @override
  String toString() {
    return r'groupAchievementsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<GroupAchievementsDtoInner>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GroupAchievementsDtoInner>?> create(Ref ref) {
    final argument = this.argument as String;
    return groupAchievements(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupAchievementsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupAchievementsHash() => r'2cfa502425593d8c4a23c570ea149d022560c5c6';

final class GroupAchievementsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<GroupAchievementsDtoInner>?>,
          String
        > {
  GroupAchievementsFamily._()
    : super(
        retry: null,
        name: r'groupAchievementsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupAchievementsProvider call(String groupId) =>
      GroupAchievementsProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupAchievementsProvider';
}
