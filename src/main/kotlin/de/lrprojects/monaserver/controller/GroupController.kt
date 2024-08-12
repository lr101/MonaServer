package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.GroupsApiDelegate
import de.lrprojects.monaserver.converter.toGroupDto
import de.lrprojects.monaserver.model.CreateGroupDto
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.UpdateGroupDto
import de.lrprojects.monaserver.service.api.GroupService
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class GroupController(private val groupService: GroupService) : GroupsApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("hasAuthority('ADMIN') || @guard.isSameUser(authentication, #createGroup.getGroupAdmin())")
    override fun addGroup(createGroup: CreateGroupDto): ResponseEntity<GroupDto> {
        log.info("Attempting to add group with admin: ${createGroup.groupAdmin}")
        val result = groupService.addGroup(createGroup)
        log.info("Group added with admin: ${createGroup.groupAdmin}")
        return ResponseEntity(result, HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteGroup(groupId: UUID): ResponseEntity<Void> {
        log.info("Attempting to delete group with ID: $groupId")
        groupService.deleteGroup(groupId)
        log.info("Group deleted with ID: $groupId")
        return ResponseEntity.ok().build()
    }

    override fun getGroup(groupId: UUID): ResponseEntity<GroupDto> {
        log.info("Attempting to get group with ID: $groupId")
        val result = groupService.getGroup(groupId)
        log.info("Retrieved group with ID: $groupId")
        return ResponseEntity.ok(result.toGroupDto())
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupAdmin(groupId: UUID): ResponseEntity<String> {
        log.info("Attempting to get group admin for group with ID: $groupId")
        val result = groupService.getGroupAdmin(groupId)
        log.info("Retrieved group admin for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupDescription(groupId: UUID): ResponseEntity<String> {
        log.info("Attempting to get group description for group with ID: $groupId")
        val result = groupService.getGroupDescription(groupId)
        log.info("Retrieved group description for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    override fun getGroupsByIds(
        ids: MutableList<UUID>?,
        search: String?,
        userId: UUID?,
        withUser: Boolean?,
        withImages: Boolean?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<GroupDto>>? {
        log.info("Attempting to get groups by IDs: $ids, search: $search, userId: $userId, withUser: $withUser")
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = groupService
            .getGroupsByIds(ids, search, withUser, userId, pageable)
            .map { it.toGroupDto(withImages) }
            .toMutableList()
        log.info("Retrieved groups by IDs")
        return ResponseEntity.ok(result)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupInviteUrl(groupId: UUID): ResponseEntity<String> {
        log.info("Attempting to get group invite URL for group with ID: $groupId")
        val result = groupService.getGroupInviteUrl(groupId)
        log.info("Retrieved group invite URL for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupLink(groupId: UUID): ResponseEntity<String> {
        log.info("Attempting to get group link for group with ID: $groupId")
        val result = groupService.getGroupLink(groupId)
        log.info("Retrieved group link for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    override fun getGroupPinImage(groupId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get group pin image for group with ID: $groupId")
        val result = groupService.getGroupPinImage(groupId)
        log.info("Retrieved group pin image for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    override fun getGroupProfileImage(groupId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get group profile image for group with ID: $groupId")
        val result = groupService.getGroupProfileImage(groupId)
        log.info("Retrieved group profile image for group with ID: $groupId")
        return ResponseEntity.ok(result)
    }

    @PreAuthorize("@guard.isGroupAdmin(authentication, #groupId)")
    override fun updateGroup(groupId: UUID, updateGroup: UpdateGroupDto): ResponseEntity<GroupDto> {
        log.info("Attempting to update group with ID: $groupId")
        val result = groupService.updateGroup(groupId, updateGroup)
        log.info("Updated group with ID: $groupId")
        return ResponseEntity.ok(result)
    }
}
