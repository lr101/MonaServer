package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Member
import org.openapitools.model.GroupSmall

interface MemberService {

    fun addMember(username: String): Group

    fun getMembers(groupId: Long): List<Member>

    fun deleteMember(username: String)

    fun getGroupsOfUser(username: String): List<GroupSmall>

}