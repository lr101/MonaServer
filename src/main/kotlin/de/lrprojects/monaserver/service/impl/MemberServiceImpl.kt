package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.convertToGroupSmall
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.MemberService
import org.openapitools.model.GroupSmall
import org.openapitools.model.Visibility
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.collections.HashSet

@Service

class MemberServiceImpl constructor(
    @Autowired val userRepository: UserRepository,
    @Autowired val groupRepository: GroupRepository
): MemberService {
    override fun addMember(username: String, groupId: Long): Group {
        val group = groupRepository.findById(groupId)
            .orElseThrow { IllegalArgumentException("Group not found") }

        val user = userRepository.findById(username)
            .orElseThrow { UserNotFoundException("User not found") }

        group.members.add(user)
        groupRepository.save(group)

        return group
    }

    override fun getMembers(groupId: Long): List<String> {
        val group = groupRepository.findById(groupId)
            .orElseThrow { IllegalArgumentException("Group not found") }
        return group.members.map { e -> e.username!! }
    }

    override fun deleteMember(username: String, groupId: Long) {
        val group = groupRepository.findById(groupId)
            .orElseThrow { IllegalArgumentException("Group not found") }
        val member = group.members.find { it.username == username }
            ?: throw UserNotFoundException("Member not found in the group")

        group.members.remove(member)
        groupRepository.save(group)
    }

    override fun getGroupsOfUser(username: String): List<GroupSmall> {
        val user = userRepository.findById(username).orElseThrow { IllegalArgumentException("User not found") }
        val users = HashSet<User>()
        users.add(user)
        return groupRepository.findGroupsByMembers(users).map { group: Group -> group.convertToGroupSmall() }
    }


}