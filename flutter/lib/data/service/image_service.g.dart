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

String _$getUserProfileHash() => r'd3bf9a07954382859850b2a3df78dee25700f4b5';

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
    r'19deab084241f73946ede146c3b6a32c6e636514';

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
    r'4bfe35f2ad5d1a8673caeb04e8ad2e9ff12cab3c';

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
    r'113e186030da4de6d2914602e672a27a5daf22b0';

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

String _$groupPinImageByIdHash() => r'42e66303d3f7e8deb25b7ebbb34899baa80b2d46';

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

@ProviderFor(pinImageBytes)
final pinImageBytesProvider = PinImageBytesFamily._();

final class PinImageBytesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          Stream<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $StreamProvider<Uint8List?> {
  PinImageBytesProvider._({
    required PinImageBytesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pinImageBytesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pinImageBytesHash();

  @override
  String toString() {
    return r'pinImageBytesProvider'
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
    return pinImageBytes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PinImageBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pinImageBytesHash() => r'719dd11c02c82c48875466de567e7a78d6650acb';

final class PinImageBytesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Uint8List?>, String> {
  PinImageBytesFamily._()
    : super(
        retry: null,
        name: r'pinImageBytesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PinImageBytesProvider call(String pinId) =>
      PinImageBytesProvider._(argument: pinId, from: this);

  @override
  String toString() => r'pinImageBytesProvider';
}
