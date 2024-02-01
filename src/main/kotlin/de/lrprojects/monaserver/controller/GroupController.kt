package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.GroupsApi
import de.lrprojects.monaserver.api.GroupsApiDelegate
import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component

@Component
class GroupController : GroupsApiDelegate {

    override fun addGroup(createGroup: CreateGroup?): ResponseEntity<Group> {
        return super.addGroup(createGroup)
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteGroup(groupId: Long?): ResponseEntity<Void> {
        return super.deleteGroup(groupId)
    }

    override fun getGroup(groupId: Long?): ResponseEntity<GroupSmall> {
        return super.getGroup(groupId)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupAdmin(groupId: Long?): ResponseEntity<Long> {
        return super.getGroupAdmin(groupId)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupDescription(groupId: Long?): ResponseEntity<String> {
        return super.getGroupDescription(groupId)
    }

    override fun getGroupsByIds(
        ids: MutableList<Long>?,
        search: String?,
        withUser: Boolean?
    ): ResponseEntity<MutableList<GroupSmall>> {
        return super.getGroupsByIds(ids, search, withUser)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupInviteUrl(groupId: Long?): ResponseEntity<String> {
        return super.getGroupInviteUrl(groupId)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupLink(groupId: Long?): ResponseEntity<String> {
        return super.getGroupLink(groupId)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupPinImage(groupId: Long?): ResponseEntity<ByteArray> {
        return super.getGroupPinImage(groupId)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupProfileImage(groupId: Long?): ResponseEntity<ByteArray> {
        return super.getGroupProfileImage(groupId)
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun updateGroup(groupId: Long?, updateGroup: UpdateGroup?): ResponseEntity<Group> {
        return super.updateGroup(groupId, updateGroup)
    }


}