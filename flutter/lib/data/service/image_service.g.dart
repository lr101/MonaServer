// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getUserProfile)
final getUserProfileProvider = GetUserProfileFamily._();

final class GetUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  GetUserProfileProvider._({
    required GetUserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getUserProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getUserProfileHash();

  @override
  String toString() {
    return r'getUserProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return getUserProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetUserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getUserProfileHash() => r'4e9e391358dc51d40325fbd4ca88a77f469b7abd';

final class GetUserProfileFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  GetUserProfileFamily._()
    : super(
        retry: null,
        name: r'getUserProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetUserProfileProvider call(String userId) =>
      GetUserProfileProvider._(argument: userId, from: this);

  @override
  String toString() => r'getUserProfileProvider';
}

@ProviderFor(getUserProfileSmall)
final getUserProfileSmallProvider = GetUserProfileSmallFamily._();

final class GetUserProfileSmallProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  GetUserProfileSmallProvider._({
    required GetUserProfileSmallFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getUserProfileSmallProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getUserProfileSmallHash();

  @override
  String toString() {
    return r'getUserProfileSmallProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return getUserProfileSmall(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetUserProfileSmallProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getUserProfileSmallHash() =>
    r'62ab157081f46e2ffff02dcf2fc4b1382ab51284';

final class GetUserProfileSmallFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  GetUserProfileSmallFamily._()
    : super(
        retry: null,
        name: r'getUserProfileSmallProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetUserProfileSmallProvider call(String userId) =>
      GetUserProfileSmallProvider._(argument: userId, from: this);

  @override
  String toString() => r'getUserProfileSmallProvider';
}

@ProviderFor(groupProfilePictureById)
final groupProfilePictureByIdProvider = GroupProfilePictureByIdFamily._();

final class GroupProfilePictureByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  GroupProfilePictureByIdProvider._({
    required GroupProfilePictureByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupProfilePictureByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupProfilePictureByIdHash();

  @override
  String toString() {
    return r'groupProfilePictureByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return groupProfilePictureById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupProfilePictureByIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupProfilePictureByIdHash() =>
    r'9a458c557a4900959238012f5475cbedd9d9fe98';

final class GroupProfilePictureByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  GroupProfilePictureByIdFamily._()
    : super(
        retry: null,
        name: r'groupProfilePictureByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupProfilePictureByIdProvider call(String groupId) =>
      GroupProfilePictureByIdProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupProfilePictureByIdProvider';
}

@ProviderFor(groupProfilePictureSmallById)
final groupProfilePictureSmallByIdProvider =
    GroupProfilePictureSmallByIdFamily._();

final class GroupProfilePictureSmallByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  GroupProfilePictureSmallByIdProvider._({
    required GroupProfilePictureSmallByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupProfilePictureSmallByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupProfilePictureSmallByIdHash();

  @override
  String toString() {
    return r'groupProfilePictureSmallByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return groupProfilePictureSmallById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupProfilePictureSmallByIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupProfilePictureSmallByIdHash() =>
    r'20b84fdad8516658fc133e920576f674fedc916a';

final class GroupProfilePictureSmallByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  GroupProfilePictureSmallByIdFamily._()
    : super(
        retry: null,
        name: r'groupProfilePictureSmallByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupProfilePictureSmallByIdProvider call(String groupId) =>
      GroupProfilePictureSmallByIdProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupProfilePictureSmallByIdProvider';
}

@ProviderFor(groupPinImageById)
final groupPinImageByIdProvider = GroupPinImageByIdFamily._();

final class GroupPinImageByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  GroupPinImageByIdProvider._({
    required GroupPinImageByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupPinImageByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupPinImageByIdHash();

  @override
  String toString() {
    return r'groupPinImageByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return groupPinImageById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupPinImageByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupPinImageByIdHash() => r'4ae617ef41c760193168d8d09c12a53a3246e981';

final class GroupPinImageByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  GroupPinImageByIdFamily._()
    : super(
        retry: null,
        name: r'groupPinImageByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupPinImageByIdProvider call(String groupId) =>
      GroupPinImageByIdProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupPinImageByIdProvider';
}

@ProviderFor(getPinImageInfo)
final getPinImageInfoProvider = GetPinImageInfoFamily._();

final class GetPinImageInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<PinImageInfo?>,
          PinImageInfo?,
          Stream<PinImageInfo?>
        >
    with $FutureModifier<PinImageInfo?>, $StreamProvider<PinImageInfo?> {
  GetPinImageInfoProvider._({
    required GetPinImageInfoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getPinImageInfoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getPinImageInfoHash();

  @override
  String toString() {
    return r'getPinImageInfoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PinImageInfo?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PinImageInfo?> create(Ref ref) {
    final argument = this.argument as String;
    return getPinImageInfo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPinImageInfoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getPinImageInfoHash() => r'a6833e7bfee57b19cdaa626f447cc415e6744883';

final class GetPinImageInfoFamily extends $Family
    with $FunctionalFamilyOverride<Stream<PinImageInfo?>, String> {
  GetPinImageInfoFamily._()
    : super(
        retry: null,
        name: r'getPinImageInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetPinImageInfoProvider call(String pinId) =>
      GetPinImageInfoProvider._(argument: pinId, from: this);

  @override
  String toString() => r'getPinImageInfoProvider';
}
