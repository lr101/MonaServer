package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupSmall

interface MemberService {

    fun addMember(username: String, groupId: Long): Group

    fun getMembers(groupId: Long): List<String>

    fun deleteMember(username: String, groupId: Long)

    fun getGroupsOfUser(username: String): List<GroupSmall>

}