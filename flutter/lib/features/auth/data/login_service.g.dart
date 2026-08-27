// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(loginService)
final loginServiceProvider = LoginServiceProvider._();

final class LoginServiceProvider
    extends $FunctionalProvider<LoginService, LoginService, LoginService>
    with $Provider<LoginService> {
  LoginServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginServiceHash();

  @$internal
  @override
  $ProviderElement<LoginService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoginService create(Ref ref) {
    return loginService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginService>(value),
    );
  }
}

String _$loginServiceHash() => r'ad15ac59c2bbed1c33552a4ff5f4f97cb536a2ca';
