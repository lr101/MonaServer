import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/repository/member_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'member_service.g.dart';

@riverpod
class MemberService extends _$MemberService {
  late IMemberRepository _memberRepository;
  late MembersApi _membersApi;
  late SessionIdentity _session;

  @override
  Stream<List<MemberEntity>> build(String groupId) {
    _memberRepository = ref.watch(memberRepositoryProvider);
    _membersApi = ref.watch(memberApiProvider);
    _session = watchSession(ref);

    fetchRemote(session: _session);

    final stream = _memberRepository.watchById(groupId);
    return stream.map(sortMembers);
  }

  Future<void> fetchRemote({required SessionIdentity session}) async {
    final members = await _membersApi.getGroupMembers(groupId);
    if (!isCurrentSession(ref, session) || members == null) return;
    for (final member in members) {
      registerUserImageSmallUrl(ref, member.userId, member.profileImageSmall);
    }
    final entity = MembersEntity(
      groupId: groupId,
      onlySession: true,
      members: members.map(MemberEntity.fromRanking).toList(),
      ttl: DateTime.now(),
    );
    if (!isCurrentSession(ref, session)) return;
    await _memberRepository.put(entity);
  }

  List<MemberEntity> sortMembers(MembersEntity? memberList) {
    final list = memberList?.members;
    if (list == null) return [];
    list.sort((a, b) => b.points - a.points);
    return list;
  }
}
