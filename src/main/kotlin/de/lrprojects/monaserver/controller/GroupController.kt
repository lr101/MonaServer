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

    override fun deleteGroup(groupId: Int?): ResponseEntity<Void> {
        return super.deleteGroup(groupId)
    }

    override fun getGroup(groupId: Int?): ResponseEntity<GroupSmall> {
        return super.getGroup(groupId)
    }

    override fun getGroupAdmin(groupId: Int?): ResponseEntity<Int> {
        return super.getGroupAdmin(groupId)
    }

    override fun getGroupDescription(groupId: Int?): ResponseEntity<String> {
        return super.getGroupDescription(groupId)
    }

    override fun getGroupIdsBySearchTerm(search: String?, withUser: Boolean?): ResponseEntity<MutableList<Int>> {
        return super.getGroupIdsBySearchTerm(search, withUser)
    }

    override fun getGroupInviteUrl(groupId: Int?): ResponseEntity<String> {
        return super.getGroupInviteUrl(groupId)
    }

    override fun getGroupLink(groupId: Int?): ResponseEntity<String> {
        return super.getGroupLink(groupId)
    }

    override fun getGroupPinImage(groupId: Int?): ResponseEntity<ByteArray> {
        return super.getGroupPinImage(groupId)
    }

    override fun getGroupProfileImage(groupId: Int?): ResponseEntity<ByteArray> {
        return super.getGroupProfileImage(groupId)
    }

    override fun getGroupsByIds(ids: MutableList<Int>?): ResponseEntity<MutableList<GroupSmall>> {
        return super.getGroupsByIds(ids)
    }

    override fun getGroupsByUsername(username: String?): ResponseEntity<MutableList<GroupSmall>> {
        return super.getGroupsByUsername(username)
    }

    override fun updateGroup(groupId: Int?, updateGroup: UpdateGroup?): ResponseEntity<Group> {
        return super.updateGroup(groupId, updateGroup)
    }


}