package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Member
import de.lrprojects.monaserver.entity.keys.EmbeddedMemberKey
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.MemberRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfileSmall
import de.lrprojects.monaserver_api.model.MemberResponseDto
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.cache.annotation.Cacheable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class MemberServiceImpl(
    val userRepository: UserRepository,
    val groupRepository: GroupRepository,
    private val memberRepository: MemberRepository,
    private val objectService: ObjectService
): MemberService {

    @Throws(EntityNotFoundException::class, UserNotFoundException::class, ComparisonException::class)
    override fun addMember(userId: UUID, groupId: UUID, inviteUrl: String?): Group {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }


        if (group.visibility == 0 || group.inviteUrl == inviteUrl) {
            val user = userRepository.findById(userId).orElseThrow { throw UserNotFoundException("User not found") }
            if (memberRepository.existsById(EmbeddedMemberKey(group, user))) {
                throw UserExistsException("User is already a member")
            }
            memberRepository.save(Member(EmbeddedMemberKey(group, user)))
            return group
        } else {
            throw ComparisonException("inviteUrl does not match")
        }


    }

    @Cacheable(value = ["groupRanking"], key = "#groupId")
    override fun getRanking(groupId: UUID): MutableList<MemberResponseDto> {
        return groupRepository.getRanking(groupId).map {
            MemberResponseDto(it[0] as UUID, it[1] as String, it[2] as Int).also {
                e -> e.profileImageSmall = objectService.getObject(getUserFileProfileSmall(e.userId))
                e.selectedBatch = it[3] as Int?
            }
        }.toMutableList()
    }

    @Throws(EntityNotFoundException::class, UserNotFoundException::class)
    @Transactional
    override fun deleteMember(userId: UUID, groupId: UUID) {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }

        val user = userRepository.findById(userId)
            .orElseThrow { UserNotFoundException("User does not exist") }

        if (user == group.groupAdmin && memberRepository.countByGroup(groupId) == 1L) {
            groupRepository.deleteById(groupId)
            log.info("Deleted group $groupId")
        } else if (user != group.groupAdmin) {
            memberRepository.deleteById_Group_IdAndId_User_Id(groupId, userId)
        } else {
            throw UserIsAdminException("User can not leave group as an admin")
        }

    }

    @Throws(UserNotFoundException::class)
    override fun getGroupsOfUser(userId: UUID): List<Group> {
        val user = userRepository.findById(userId).orElseThrow { UserNotFoundException("User not found") }
        val users = mutableSetOf(user)
        return groupRepository.findAllByMembersIn(mutableSetOf(users))
    }

    override fun getGroupOfUserOrPublic(userId: UUID): List<Group> {
        val user = userRepository.findById(userId).orElseThrow { UserNotFoundException("User not found") }
        val users = mutableSetOf(user)
        return groupRepository.findAllByMembersInOrVisibility(mutableSetOf(users), 0)
    }

    override fun isInGroup(group: Group, userId: UUID): Boolean {
        return memberRepository.existsById_Group_IdAndId_User_Id(group.id!!, userId)
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}