package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.MemberResponseDto
import de.lrprojects.monaserver.model.RankingResponseDto
import java.util.*

interface MemberService {

    fun addMember(userId: UUID, groupId: UUID, inviteUrl: String?): Group

    fun getMembers(groupId: UUID): List<MemberResponseDto>

    fun getRanking(groupId: UUID): MutableList<RankingResponseDto>

    fun deleteMember(userId: UUID, groupId: UUID)

    fun getGroupsOfUser(userId: UUID): List<GroupDto>

    fun getGroupOfUserOrPublic(userId: UUID): List<GroupDto>

    fun isInGroup(group: Group): Boolean;

}