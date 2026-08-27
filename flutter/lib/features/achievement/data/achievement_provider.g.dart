// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Achievements)
final achievementsProvider = AchievementsProvider._();

final class AchievementsProvider
    extends
        $AsyncNotifierProvider<Achievements, List<UserAchievementsDtoInner>> {
  AchievementsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'achievementsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$achievementsHash();

  @$internal
  @override
  Achievements create() => Achievements();
}

String _$achievementsHash() => r'641e221073fa798a4a9cc29f2e0ec7a1e981c0a7';

abstract class _$Achievements
    extends $AsyncNotifier<List<UserAchievementsDtoInner>> {
  FutureOr<List<UserAchievementsDtoInner>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<UserAchievementsDtoInner>>,
              List<UserAchievementsDtoInner>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<UserAchievementsDtoInner>>,
                List<UserAchievementsDtoInner>
              >,
              AsyncValue<List<UserAchievementsDtoInner>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
