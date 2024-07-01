package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupSmallDto
import de.lrprojects.monaserver.model.MemberResponseDto
import java.util.*

interface MemberService {

    fun addMember(userId: UUID, groupId: UUID, inviteUrl: String?): Group

    fun getMembers(groupId: UUID): List<MemberResponseDto>

    fun deleteMember(userId: UUID, groupId: UUID)

    fun getGroupsOfUser(userId: UUID): List<GroupSmallDto>

    fun getGroupOfUserOrPublic(userId: UUID): List<GroupSmallDto>

    fun isInGroup(group: Group): Boolean;

}