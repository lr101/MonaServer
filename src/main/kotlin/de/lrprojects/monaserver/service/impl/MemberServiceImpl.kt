package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.convertToGroupSmall
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.Member
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.jvm.Throws

@Service
@Transactional
class MemberServiceImpl constructor(
    @Autowired val userRepository: UserRepository,
    @Autowired val groupRepository: GroupRepository
): MemberService {

    @Throws(EntityNotFoundException::class, UserNotFoundException::class, ComparisonException::class)
    override fun addMember(username: String, groupId: Long, inviteUrl: String?): Group {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }


        if (group.visibility == 0 || group.inviteUrl == inviteUrl) {
            val user = userRepository.findById(username)
                .orElseThrow { UserNotFoundException("User not found") }
            if (group.members.contains(user)) {
                throw UserExistsException("User is already a member")
            }
            user.groups.add(group)
            userRepository.save(user)
            return group
        } else {
            throw ComparisonException("inviteUrl does not match")
        }


    }

    @Throws(EntityNotFoundException::class)
    override fun getMembers(groupId: Long): List<Member> {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.members.map { e -> Member(e.username!!) }
    }

    @Throws(EntityNotFoundException::class, UserNotFoundException::class)
    override fun deleteMember(username: String, groupId: Long) {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }

        val user = userRepository.findById(username)
            .orElseThrow { UserNotFoundException("User does not exist") }

        user.groups.find { it.groupId == groupId }
            ?: throw UserNotFoundException("Member not found in the group")

        if (user == group.groupAdmin && group.members.size == 1) {
            groupRepository.delete(group)
        } else if (user != group.groupAdmin) {
            user.groups.remove(group)
            userRepository.save(user)
        } else {
            throw UserIsAdminException("User can not leave group as an admin")
        }

    }

    @Throws(UserNotFoundException::class)
    override fun getGroupsOfUser(username: String): List<GroupSmall> {
        val user = userRepository.findById(username).orElseThrow { UserNotFoundException("User not found") }
        val users = mutableSetOf(user)
        return groupRepository.findAllByMembersIn(mutableSetOf(users)).map { group: Group -> group.convertToGroupSmall() }
    }

    override fun getGroupOfUserOrPublic(username: String): List<GroupSmall> {
        val user = userRepository.findById(username).orElseThrow { UserNotFoundException("User not found") }
        val users = mutableSetOf(user)
        return groupRepository.findAllByMembersInOrVisibility(mutableSetOf(users), 0).map { group: Group -> group.convertToGroupSmall() }
    }

    override fun isInGroup(group: Group): Boolean {
        val user = userRepository.findById(SecurityContextHolder.getContext().authentication.name).orElseThrow { UserNotFoundException("User not found") }
        return group.members.contains(user);
    }


}