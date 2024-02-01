package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.Member

interface MemberService {

    fun addMember(username: String, groupId: Long, inviteUrl: String?): Group

    fun getMembers(groupId: Long): List<Member>

    fun deleteMember(username: String, groupId: Long)

    fun getGroupsOfUser(username: String): List<GroupSmall>

}