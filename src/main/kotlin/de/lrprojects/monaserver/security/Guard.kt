package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.PinService
import org.slf4j.LoggerFactory
import org.springframework.security.core.Authentication
import org.springframework.stereotype.Component
import java.util.*


@Component
class Guard(
    private val memberService: MemberService,
    private val groupService: GroupService,
    private val groupRepository: GroupRepository,
    private val pinService: PinService,
    private val userRepository: UserRepository
){

    fun isGroupVisible(authentication: Authentication, groupId: UUID): Boolean {
        log.info("Checking if group with ID: $groupId is visible for user: ${authentication.name}")
        val name = UUID.fromString(authentication.name)
        return try {
            val result = groupService.getGroup(groupId)
            result.visibility == 0 || memberService.getMembers(groupId).any{ name == it.userId}
        } catch (e: Exception) {
            log.warn("Failed to authenticate group is visible")
            false
        }
    }


    fun isGroupAdmin(authentication: Authentication, groupId: UUID): Boolean {
        log.info("""Checking if group with ID: $groupId is admin for user: ${authentication.name}""")
        val name = UUID.fromString(authentication.name)
        return try {
            val result = groupService.getGroup(groupId)
            return name == result.groupAdmin?.id
        } catch (e: Exception) {
            log.warn("Failed to authenticate group is admin")
            false
        }
    }

    fun isGroupMember(authentication: Authentication, groupId: UUID): Boolean {
        log.info("""Checking if group with ID: $groupId is member for user: ${authentication.name}""")
        val name = UUID.fromString(authentication.name)
        return try {
            val user = userRepository.findById(name)
            return memberService.getMembers(groupId).any { e -> e.userId == user.get().id }
        } catch (e: Exception) {
            log.warn("Failed to authenticate group is member")
            false
        }
    }

    fun isSameUser(authentication: Authentication, userId: UUID): Boolean {
        log.info("Checking if user with ID: $userId is same as user: ${authentication.name}")
        return try {
            return UUID.fromString(authentication.name) == userId
        } catch (e: Exception) {
            log.warn("Failed to authenticate same user")
            false
        }
    }

    fun isPinGroupAdmin(authentication: Authentication, pinId: UUID): Boolean {
        log.info("Checking if pin with ID: $pinId is admin for user: ${authentication.name}")
        val name = UUID.fromString(authentication.name)
        return try {
            val result = groupService.getGroupOfPin(pinId)
            return name == result.groupAdmin?.id
        } catch (e: Exception) {
            log.warn("Failed to authenticate pin is admin")
            false
        }
    }

    fun isPinGroupMember(authentication: Authentication, pinId: UUID): Boolean {
        log.info("Checking if pin with ID: $pinId is member for user: ${authentication.name}")
        val name = UUID.fromString(authentication.name)
        return try {
            val result = groupRepository.findByPinId(pinId)
            return result.groupAdmin?.id == name
        } catch (e: Exception) {
            log.warn("Failed to authenticate pin is member")
            false
        }
    }

    fun isPinPublicOrMember(authentication: Authentication, pinId: UUID) : Boolean {
        log.info("Checking if pin with ID: $pinId is public or member for user: ${authentication.name}")
        return try {
            return isPinGroupMember(authentication, pinId) || groupService.getGroupOfPin(pinId).visibility == 0
        } catch (e: Exception) {
            log.warn("Failed to authenticate pin is public or user is member")
            false
        }
    }

    fun isPinsPublicOrMember(authentication: Authentication, ids: MutableList<UUID>?) : Boolean {
        log.info("Checking if pins with IDs: $ids are public or member for user: ${authentication.name}")
        return try {
            ids?.all { isPinPublicOrMember(authentication, it)}.let { true }
        } catch (e: Exception) {
            log.warn("Failed to authenticate pins are public or user is member")
            false
        }
    }

    fun isPinCreator(authentication: Authentication, pinId: UUID): Boolean {
        log.info("Checking if pin with ID: $pinId is creator for user: ${authentication.name}")
        val name = UUID.fromString(authentication.name)
        return try {
            val result = pinService.getPin(pinId)
            return result.user?.id == name
        } catch (e: Exception) {
            log.warn("Failed to authenticate pin is creator")
            false
        }
    }

    fun isPinsCreator(authentication: Authentication, pinIds: List<UUID>?): Boolean {
        log.info("Checking if pins with ID: $pinIds is creator for user: ${authentication.name}")
        val name = UUID.fromString(authentication.name)
        return try {
            if (pinIds == null) return true
            return pinIds.all { pinService.getPin(it).user?.id == name }.let { true }
        } catch (e: Exception) {
            log.warn("Failed to authenticate multiple pins is creator")
            false
        }
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}