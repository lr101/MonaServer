package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.MembersApi
import de.lrprojects.monaserver.model.ApiGroupsGroupIdMembersPostRequest
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.Member
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class MemberController : MembersApi {
    override fun apiGroupsGroupIdMembersPost(
        groupId: Long?,
        apiGroupsGroupIdMembersPostRequest: ApiGroupsGroupIdMembersPostRequest?
    ): ResponseEntity<Group> {
        return super.apiGroupsGroupIdMembersPost(groupId, apiGroupsGroupIdMembersPostRequest)
    }

    override fun deleteMemberFromGroup(groupId: Long?): ResponseEntity<Void> {
        return super.deleteMemberFromGroup(groupId)
    }

    override fun getGroupMembers(groupId: Long?): ResponseEntity<MutableList<Member>> {
        return super.getGroupMembers(groupId)
    }

}