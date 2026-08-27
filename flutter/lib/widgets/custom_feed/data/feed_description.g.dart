// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_description.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedDescription)
final feedDescriptionProvider = FeedDescriptionFamily._();

final class FeedDescriptionProvider
    extends $NotifierProvider<FeedDescription, bool> {
  FeedDescriptionProvider._({
    required FeedDescriptionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'feedDescriptionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$feedDescriptionHash();

  @override
  String toString() {
    return r'feedDescriptionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FeedDescription create() => FeedDescription();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedDescriptionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$feedDescriptionHash() => r'4e20e4c6792428ebd9a65a43cfda7fabb4928471';

final class FeedDescriptionFamily extends $Family
    with $ClassFamilyOverride<FeedDescription, bool, bool, bool, String> {
  FeedDescriptionFamily._()
    : super(
        retry: null,
        name: r'feedDescriptionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeedDescriptionProvider call(String pinId) =>
      FeedDescriptionProvider._(argument: pinId, from: this);

  @override
  String toString() => r'feedDescriptionProvider';
}

abstract class _$FeedDescription extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get pinId => _$args;

  bool build(String pinId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(FeedDescriptionHeight)
final feedDescriptionHeightProvider = FeedDescriptionHeightFamily._();

final class FeedDescriptionHeightProvider
    extends $NotifierProvider<FeedDescriptionHeight, double> {
  FeedDescriptionHeightProvider._({
    required FeedDescriptionHeightFamily super.from,
    required PinEntity super.argument,
  }) : super(
         retry: null,
         name: r'feedDescriptionHeightProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$feedDescriptionHeightHash();

  @override
  String toString() {
    return r'feedDescriptionHeightProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FeedDescriptionHeight create() => FeedDescriptionHeight();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedDescriptionHeightProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$feedDescriptionHeightHash() =>
    r'73472a1880b28feb5d279e29d11dcc35b1760628';

final class FeedDescriptionHeightFamily extends $Family
    with
        $ClassFamilyOverride<
          FeedDescriptionHeight,
          double,
          double,
          double,
          PinEntity
        > {
  FeedDescriptionHeightFamily._()
    : super(
        retry: null,
        name: r'feedDescriptionHeightProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeedDescriptionHeightProvider call(PinEntity pin) =>
      FeedDescriptionHeightProvider._(argument: pin, from: this);

  @override
  String toString() => r'feedDescriptionHeightProvider';
}

abstract class _$FeedDescriptionHeight extends $Notifier<double> {
  late final _$args = ref.$arg as PinEntity;
  PinEntity get pin => _$args;

  double build(PinEntity pin);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
