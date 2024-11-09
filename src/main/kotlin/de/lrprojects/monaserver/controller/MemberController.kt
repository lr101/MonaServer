package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.converter.toGroupDto
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver_api.api.MembersApiDelegate
import de.lrprojects.monaserver_api.model.GroupDto
import de.lrprojects.monaserver_api.model.MemberResponseDto
import de.lrprojects.monaserver_api.model.RankingResponseDto
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class MemberController(
    private val memberService: MemberService,
    private val objectService: ObjectService
) : MembersApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun joinGroup(
        groupId: UUID,
        userId: UUID,
        inviteUrl: String?
    ): ResponseEntity<GroupDto> {
        log.info("User $userId attempting to join group $groupId with inviteUrl: $inviteUrl")
        val group = memberService.addMember(userId, groupId, inviteUrl)
        log.info("User $userId joined group $groupId")
        return ResponseEntity(group.toGroupDto(memberService, true, objectService), HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId) || @guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteMemberFromGroup(groupId: UUID, userId: UUID): ResponseEntity<Void>? {
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
    override fun getGroupMembers(groupId: UUID): ResponseEntity<List<MemberResponseDto>> {
        log.info("Attempting to get members for group $groupId")
        val members = memberService.getMembers(groupId)
        log.info("Retrieved members for group $groupId")
        return ResponseEntity.ok().body(members)
    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupRanking(groupId: UUID): ResponseEntity<List<RankingResponseDto>> {
        log.info("Attempting to get ranking for group $groupId")
        val members = memberService.getRanking(groupId)
        log.info("Successfully retrieved ranking for group $groupId")
        return ResponseEntity.ok().body(members)
    }
}
