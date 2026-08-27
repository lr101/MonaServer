// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'view_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ViewService)
final viewServiceProvider = ViewServiceProvider._();

final class ViewServiceProvider
    extends $NotifierProvider<ViewService, ViewState> {
  ViewServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewServiceHash();

  @$internal
  @override
  ViewService create() => ViewService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewState>(value),
    );
  }
}

String _$viewServiceHash() => r'0ad37bd65d092310611066e5788a073a86361647';

abstract class _$ViewService extends $Notifier<ViewState> {
  ViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ViewState, ViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ViewState, ViewState>,
              ViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
