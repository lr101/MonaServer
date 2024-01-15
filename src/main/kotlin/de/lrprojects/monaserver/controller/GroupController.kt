package de.lrprojects.monaserver.controller

import org.openapitools.api.GroupsApi
import org.openapitools.model.*
import org.springframework.http.ResponseEntity
import org.springframework.web.context.request.NativeWebRequest
import java.util.*

class GroupController : GroupsApi {
    override fun addGroup(createGroup: CreateGroup?): ResponseEntity<Group> {
        return super.addGroup(createGroup)
    }

    override fun deleteGroup(groupId: Long?): ResponseEntity<Void> {
        return super.deleteGroup(groupId)
    }

    override fun getGroup(groupId: Long?): ResponseEntity<GroupSmall> {
        return super.getGroup(groupId)
    }

    override fun getGroupAdmin(groupId: Long?): ResponseEntity<Long> {
        return super.getGroupAdmin(groupId)
    }

    override fun getGroupDescription(groupId: Long?): ResponseEntity<String> {
        return super.getGroupDescription(groupId)
    }

    override fun getGroupIdsBySearchTerm(search: String?, withUser: Boolean?): ResponseEntity<MutableList<Long>> {
        return super.getGroupIdsBySearchTerm(search, withUser)
    }

    override fun getGroupInviteUrl(groupId: Long?): ResponseEntity<String> {
        return super.getGroupInviteUrl(groupId)
    }

    override fun getGroupLink(groupId: Long?): ResponseEntity<String> {
        return super.getGroupLink(groupId)
    }

    override fun getGroupPinImage(groupId: Long?): ResponseEntity<ByteArray> {
        return super.getGroupPinImage(groupId)
    }

    override fun getGroupProfileImage(groupId: Long?): ResponseEntity<ByteArray> {
        return super.getGroupProfileImage(groupId)
    }

    override fun getGroupsByIds(ids: MutableList<Long>?): ResponseEntity<MutableList<GroupSmall>> {
        return super.getGroupsByIds(ids)
    }

    override fun getGroupsByUsername(username: String?): ResponseEntity<MutableList<GroupSmall>> {
        return super.getGroupsByUsername(username)
    }

    override fun updateGroup(groupId: Long?, updateGroup: UpdateGroup?): ResponseEntity<Group> {
        return super.updateGroup(groupId, updateGroup)
    }


}