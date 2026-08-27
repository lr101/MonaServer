
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reachability_service.g.dart';

@Riverpod(keepAlive: true)
Stream<bool> reachabilityService(Ref ref) {
  return Stream<Future<bool>>.periodic(const Duration(seconds: 10), (_) async {
    try {
      final result = await ref.watch(userApiProvider).getUser(ref.watch(globalDataServiceProvider).userId!);
      return result != null;
    } catch (e) {
      return false;
    }
  }).asyncMap((e) => e);
}
