package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.Member
import java.util.*

interface MemberService {

    fun addMember(userId: UUID, groupId: UUID, inviteUrl: String?): Group

    fun getMembers(groupId: UUID): List<Member>

    fun deleteMember(userId: UUID, groupId: UUID)

    fun getGroupsOfUser(userId: UUID): List<GroupSmall>

    fun getGroupOfUserOrPublic(userId: UUID): List<GroupSmall>

    fun isInGroup(group: Group): Boolean;

}