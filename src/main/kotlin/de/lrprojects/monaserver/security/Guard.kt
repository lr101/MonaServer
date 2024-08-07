package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.model.Visibility
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.PinService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.core.Authentication
import org.springframework.stereotype.Component
import java.util.*


@Component
class Guard (
    @Autowired val memberService: MemberService,
    @Autowired val groupService: GroupService,
    @Autowired val groupRepository: GroupRepository,
    @Autowired val pinService: PinService,
    @Autowired val userRepository: UserRepository
){

    fun isGroupVisible(authentication: Authentication, groupId: UUID): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroup(groupId)
            val user = userRepository.findByUsername(name)
            result.visibility == Visibility.NUMBER_0.value || memberService.getMembers(groupId).any{ user.get().id == it.userId}
        } catch (e: Exception) {
            false
        }
    }


    fun isGroupAdmin(authentication: Authentication, groupId: UUID): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroupAdmin(groupId)
            return name.equals(result)
        } catch (e: Exception) {
            false
        }
    }

    fun isGroupMember(authentication: Authentication, groupId: UUID): Boolean {
        val name = authentication.name
        return try {
            val user = userRepository.findByUsername(name)
            return memberService.getMembers(groupId).any { e -> e.userId == user.get().id }
        } catch (e: Exception) {
            false
        }
    }

    fun isSameUser(authentication: Authentication, username: UUID): Boolean {
        return try {
            val user = userRepository.findById(username).get()
            return user.username == authentication.name
        } catch (e: Exception) {
            false
        }
    }

    fun isPinGroupAdmin(authentication: Authentication, pinId: UUID): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroupOfPin(pinId)
            return name.equals(result.groupAdmin)
        } catch (e: Exception) {
            false
        }
    }

    fun isPinGroupMember(authentication: Authentication, pinId: UUID): Boolean {
        val name = authentication.name
        return try {
            val result = groupRepository.getGroupMembersByPinId(pinId)
            return result.contains(name)
        } catch (e: Exception) {
            false
        }
    }

    fun isPinPublicOrMember(authentication: Authentication, pinId: UUID) : Boolean {
        return try {
            return isPinGroupMember(authentication, pinId) || groupService.getGroupOfPin(pinId).visibility == 0
        } catch (e: Exception) {
            false
        }
    }

    fun isPinsPublicOrMember(authentication: Authentication, ids: MutableList<UUID>?) : Boolean {
        return try {
            ids?.all { isPinPublicOrMember(authentication, it)}.let { true }
        } catch (e: Exception) {
            false
        }
    }

    fun isPinCreator(authentication: Authentication, pinId: UUID): Boolean {
        val name = authentication.name
        return try {
            val result = pinService.getPin(pinId)
            return result.user!!.username == name
        } catch (e: Exception) {
            false
        }
    }
}