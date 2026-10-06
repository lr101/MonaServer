// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_xp_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userXp)
final userXpProvider = UserXpFamily._();

final class UserXpProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserXpDto?>,
          UserXpDto?,
          FutureOr<UserXpDto?>
        >
    with $FutureModifier<UserXpDto?>, $FutureProvider<UserXpDto?> {
  UserXpProvider._({
    required UserXpFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userXpProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userXpHash();

  @override
  String toString() {
    return r'userXpProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserXpDto?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UserXpDto?> create(Ref ref) {
    final argument = this.argument as String;
    return userXp(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserXpProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userXpHash() => r'e70caf000563e2bfac10a566c4720b8acc36c86a';

final class UserXpFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserXpDto?>, String> {
  UserXpFamily._()
    : super(
        retry: null,
        name: r'userXpProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserXpProvider call(String userId) =>
      UserXpProvider._(argument: userId, from: this);

  @override
  String toString() => r'userXpProvider';
}
