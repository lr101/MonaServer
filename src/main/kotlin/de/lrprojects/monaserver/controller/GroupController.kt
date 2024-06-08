package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.GroupsApiDelegate
import de.lrprojects.monaserver.converter.convertToGroupSmall
import de.lrprojects.monaserver.excepetion.ImageNotSquareException
import de.lrprojects.monaserver.excepetion.ProfileImageException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup
import de.lrprojects.monaserver.service.api.GroupService
import jakarta.persistence.EntityNotFoundException
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class GroupController (private val groupService: GroupService) : GroupsApiDelegate {

    @PreAuthorize("hasAuthority('ADMIN') || @guard.isSameUser(authentication, #createGroup.getGroupAdmin())")
    override fun addGroup(createGroup: CreateGroup): ResponseEntity<Group> {
        return try {
            val result = groupService.addGroup(createGroup)
            ResponseEntity(result, HttpStatus.CREATED)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: ProfileImageException) {
            ResponseEntity(HttpStatus.BAD_REQUEST)
        } catch (e: ImageNotSquareException) {
            ResponseEntity.badRequest().build()
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

   @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteGroup(groupId: UUID): ResponseEntity<Void> {
        return try {
            groupService.deleteGroup(groupId)
            ResponseEntity.ok().build()
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun getGroup(groupId: UUID): ResponseEntity<GroupSmall> {
        return try {
            val result = groupService.getGroup(groupId)
            ResponseEntity.ok(result.convertToGroupSmall())
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupAdmin(groupId: UUID): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupAdmin(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupDescription(groupId: UUID): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupDescription(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun getGroupsByIds(
        ids: MutableList<UUID>?,
        search: String?,
        userId: UUID?,
        withUser: Boolean?
    ): ResponseEntity<MutableList<GroupSmall>>? {
        return try {
            val result = groupService.getGroupsByIds(ids, search, withUser, userId).toMutableList()
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: AssertionError) {
            ResponseEntity.badRequest().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupInviteUrl(groupId: UUID): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupInviteUrl(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupLink(groupId: UUID): ResponseEntity<String> {
        return try {
            val result = groupService.getGroupLink(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupPinImage(groupId: UUID): ResponseEntity<ByteArray> {
        return try {
            val result = groupService.getGroupPinImage(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun getGroupProfileImage(groupId: UUID): ResponseEntity<ByteArray> {
        return try {
            val result = groupService.getGroupProfileImage(groupId)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun updateGroup(groupId: UUID, updateGroup: UpdateGroup): ResponseEntity<Group> {
        return try {
            val result = groupService.updateGroup(groupId, updateGroup)
            ResponseEntity.ok(result)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: ImageNotSquareException) {
            ResponseEntity.badRequest().build()
        } catch (e: UserNotFoundException) {
            ResponseEntity.badRequest().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }


}