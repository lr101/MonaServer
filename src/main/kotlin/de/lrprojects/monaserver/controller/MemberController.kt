package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.MembersApiDelegate
import de.lrprojects.monaserver.converter.toGroupModel
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.JoinGroupRequest
import de.lrprojects.monaserver.model.MemberResponseDto
import de.lrprojects.monaserver.service.api.MemberService
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class MemberController(private val memberService: MemberService) : MembersApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun joinGroup(
        groupId: UUID,
        userId: UUID,
        joinGroupRequest: JoinGroupRequest?
    ): ResponseEntity<GroupDto> {
        log.info("User $userId attempting to join group $groupId with inviteUrl: ${joinGroupRequest?.inviteUrl}")
        val group = memberService.addMember(userId, groupId, joinGroupRequest?.inviteUrl)
        log.info("User $userId joined group $groupId")
        return ResponseEntity(group.toGroupModel(), HttpStatus.CREATED)
    }

    @PreAuthorize("authentication.name.equals(#userId) || @guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteMemberFromGroup(groupId: UUID, userId: UUID): ResponseEntity<Void> {
        log.info("Attempting to delete user $userId from group $groupId")
        return try {
            memberService.deleteMember(userId, groupId)
            log.info("User $userId deleted from group $groupId")
            ResponseEntity.ok().build()
        } catch (e: UserIsAdminException) {
            log.warn("Failed to delete user $userId from group $groupId: user is an admin")
            ResponseEntity(HttpStatus.CONFLICT)
        }
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupMembers(groupId: UUID): ResponseEntity<MutableList<MemberResponseDto>> {
        log.info("Attempting to get members for group $groupId")
        val members = memberService.getMembers(groupId).toMutableList()
        log.info("Retrieved members for group $groupId")
        return ResponseEntity.ok().body(members)
    }
}
