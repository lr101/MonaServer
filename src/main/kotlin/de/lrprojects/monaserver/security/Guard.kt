package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.model.Visibility
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.MemberService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.core.Authentication
import org.springframework.stereotype.Component


@Component
class Guard (
    @Autowired val memberService: MemberService,
    @Autowired val groupService: GroupService){

    fun checkGroupId(authentication: Authentication, groupId: Long): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroup(groupId)
            result.visibility == Visibility.NUMBER_0 || memberService.getMembers(groupId).any{ it.username.equals(name)}
        } catch (e: Exception) {
            false
        }
    }


    fun checkGroupAdmin(authentication: Authentication, groupId: Long): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroupAdmin(groupId)
            return name.equals(result)
        } catch (e: Exception) {
            false
        }
    }

    fun checkPinGroup(authentication: Authentication, groupId: Long): Boolean {
        val name = authentication.name
        return try {
            val result = groupService.getGroupAdmin(groupId)
            return name.equals(result)
        } catch (e: Exception) {
            false
        }
    }
}