import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_edit_service.g.dart';


@riverpod
class GroupEditService extends _$GroupEditService {

  @override
  String build() => ref.watch(globalDataServiceProvider).userId!;

  // ignore: use_setters_to_change_properties
  void updateAdminId(String adminId) {
    state = adminId;
  }
}
