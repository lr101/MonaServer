package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.MembersApi
import de.lrprojects.monaserver.api.MembersApiDelegate
import de.lrprojects.monaserver.converter.toGroupModel
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.ApiGroupsGroupIdMembersPostRequest
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.Member
import de.lrprojects.monaserver.service.api.MemberService
import jakarta.persistence.EntityNotFoundException
import mu.KotlinLogging
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component


@Component
class MemberController (@Autowired val memberService: MemberService) : MembersApiDelegate {

    private val logger = KotlinLogging.logger {}

    override fun apiGroupsGroupIdMembersPost(
        groupId: Long,
        username: String,
        apiGroupsGroupIdMembersPostRequest: ApiGroupsGroupIdMembersPostRequest?
    ): ResponseEntity<Group> {
        return try {
            val group = memberService.addMember(username, groupId, apiGroupsGroupIdMembersPostRequest?.inviteUrl)
            ResponseEntity(group.toGroupModel(), HttpStatus.CREATED)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: ComparisonException) {
            ResponseEntity(HttpStatus.BAD_REQUEST)
        } catch (e: UserExistsException) {
            ResponseEntity(HttpStatus.CONFLICT)
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("authentication.name.equals(#username) || @guard.isGroupAdmin(authentication, #groupId)")
    override fun deleteMemberFromGroup(groupId: Long, username: String): ResponseEntity<Void> {
        return try {
            memberService.deleteMember(username, groupId)
            ResponseEntity.ok().build()
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        }catch (e: UserIsAdminException) {
            ResponseEntity(HttpStatus.CONFLICT)
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isGroupVisible(authentication, #groupId)")
    override fun getGroupMembers(groupId: Long): ResponseEntity<MutableList<Member>> {
        return try {
            val members = memberService.getMembers(groupId).toMutableList()
            ResponseEntity.ok().body(members)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

}