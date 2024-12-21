package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver_api.model.MemberResponseDto
import java.util.*

interface MemberService {

    fun addMember(userId: UUID, groupId: UUID, inviteUrl: String?): Group

    fun getRanking(groupId: UUID): MutableList<MemberResponseDto>

    fun deleteMember(userId: UUID, groupId: UUID)

    fun getGroupsOfUser(userId: UUID): List<Group>

    fun getGroupOfUserOrPublic(userId: UUID): List<Group>

    fun isInGroup(group: Group): Boolean

}