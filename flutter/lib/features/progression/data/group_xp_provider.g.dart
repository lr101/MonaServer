// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_xp_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(groupProgression)
final groupProgressionProvider = GroupProgressionFamily._();

final class GroupProgressionProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupProgressionDto?>,
          GroupProgressionDto?,
          FutureOr<GroupProgressionDto?>
        >
    with
        $FutureModifier<GroupProgressionDto?>,
        $FutureProvider<GroupProgressionDto?> {
  GroupProgressionProvider._({
    required GroupProgressionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupProgressionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupProgressionHash();

  @override
  String toString() {
    return r'groupProgressionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GroupProgressionDto?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GroupProgressionDto?> create(Ref ref) {
    final argument = this.argument as String;
    return groupProgression(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupProgressionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupProgressionHash() => r'f0c2d7f3f859cbd456f2f597c7ead16defc3609a';

final class GroupProgressionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GroupProgressionDto?>, String> {
  GroupProgressionFamily._()
    : super(
        retry: null,
        name: r'groupProgressionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupProgressionProvider call(String groupId) =>
      GroupProgressionProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupProgressionProvider';
}
