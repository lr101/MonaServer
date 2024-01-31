package de.lrprojects.monaserver.controller

import org.openapitools.api.MembersApi
import org.openapitools.model.ApiGroupsGroupIdMembersPostRequest
import org.openapitools.model.Group
import org.openapitools.model.Member
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