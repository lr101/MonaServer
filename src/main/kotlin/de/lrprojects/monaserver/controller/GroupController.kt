package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.GroupsApi
import de.lrprojects.monaserver.api.GroupsApiDelegate
import de.lrprojects.monaserver.converter.convertToGroupSmall
import de.lrprojects.monaserver.excepetion.ProfileImageException
import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup
import de.lrprojects.monaserver.service.api.GroupService
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.lang.AssertionError

@Component
class GroupController (@Autowired val groupService: GroupService) : GroupsApiDelegate {

    override fun addGroup(createGroup: CreateGroup): ResponseEntity<Group> {
        return try {
            val result = groupService.addGroup(createGroup)
            ResponseEntity(result, HttpStatus.CREATED)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: ProfileImageException) {
            ResponseEntity(HttpStatus.BAD_REQUEST)
        }
    }

   @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteGroup(groupId: Long): ResponseEntity<Void> {
        return try {
            groupService.deleteGroup(groupId)
            ResponseEntity.ok().build()
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    override fun getGroup(groupId: Long): ResponseEntity<GroupSmall> {
        return try {
            val result = groupService.getGroup(groupId)
            ResponseEntity.ok(result.convertToGroupSmall())
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupAdmin(groupId: Long): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupAdmin(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupDescription(groupId: Long): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupDescription(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    override fun getGroupsByIds(
        ids: MutableList<Long>?,
        search: String?,
        username: String?,
        withUser: Boolean?
    ): ResponseEntity<MutableList<GroupSmall>>? {
        return try {
            val result = groupService.getGroupsByIds(ids, search, withUser, username).toMutableList()
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: AssertionError) {
            ResponseEntity.badRequest().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupInviteUrl(groupId: Long): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupInviteUrl(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupLink(groupId: Long): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupLink(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupPinImage(groupId: Long): ResponseEntity<ByteArray> {
        return try {
            val result = groupService.getGroupPinImage(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    override fun getGroupProfileImage(groupId: Long): ResponseEntity<ByteArray> {
        return try {
            val result = groupService.getGroupProfileImage(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun updateGroup(groupId: Long, updateGroup: UpdateGroup): ResponseEntity<Group> {
        return try {
            val result = groupService.updateGroup(groupId, updateGroup)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }
    }


}