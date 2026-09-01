import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/repository/member_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'member_service.g.dart';

@riverpod
class MemberService extends _$MemberService {
  late IMemberRepository _memberRepository;
  late MembersApi _membersApi;
  late AccountDataSessionGuard _sessionGuard;

  @override
  Stream<List<MemberEntity>> build(String groupId) {
    _memberRepository = ref.watch(memberRepositoryProvider);
    _membersApi = ref.watch(memberApiProvider);
    _sessionGuard = ref.watch(accountDataSessionGuardProvider);

    fetchRemote(_sessionGuard.generation);

    final stream = _memberRepository.watchById(groupId);
    return stream.map(sortMembers);
  }

  Future<void> fetchRemote(int generation) async {
    final members = await _membersApi.getGroupMembers(groupId);
    if (members == null) return;
    final entity = MembersEntity(
      groupId: groupId,
      onlySession: true,
      members: members.map(MemberEntity.fromRanking).toList(),
      ttl: DateTime.now(),
    );
    await _sessionGuard.runIfCurrent(
      generation,
      () => _memberRepository.put(entity),
    );
  }

  List<MemberEntity> sortMembers(MembersEntity? memberList) {
    final list = memberList?.members;
    if (list == null) return [];
    list.sort((a, b) => b.points - a.points);
    return list;
  }
}
