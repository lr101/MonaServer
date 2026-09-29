// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_review_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppReviewState)
final appReviewStateProvider = AppReviewStateProvider._();

final class AppReviewStateProvider
    extends $NotifierProvider<AppReviewState, bool> {
  AppReviewStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appReviewStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appReviewStateHash();

  @$internal
  @override
  AppReviewState create() => AppReviewState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appReviewStateHash() => r'45b9ecc45a4516c99b639d25a815c16a6376006c';

abstract class _$AppReviewState extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
