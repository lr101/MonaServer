package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Member
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserIsAdminException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.EmbeddedMemberKey
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.MemberRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfileSmall
import de.lrprojects.monaserver_api.model.MemberResponseDto
import de.lrprojects.monaserver_api.model.RankingResponseDto
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.cache.annotation.CacheEvict
import org.springframework.cache.annotation.Cacheable
import org.springframework.cache.annotation.Caching
import org.springframework.security.core.context.SecurityContextHolder
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
    @Caching( evict = [
        CacheEvict(value = ["userGroups"], key = "#userId"),
        CacheEvict(value = ["groupMembers"], key = "#groupId"),
        CacheEvict(value = ["isInGroup"], key = "{#groupId, #userId}"),
        CacheEvict(value = ["groupRanking"], key = "#groupId")
    ])
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

    @Throws(EntityNotFoundException::class)
    @Cacheable(value = ["groupMembers"], key = "#groupId")
    override fun getMembers(groupId: UUID): List<MemberResponseDto> {
        return groupRepository.findMembersByGroupId(groupId).map { MemberResponseDto(it) }
    }

    @Cacheable(value = ["groupRanking"], key = "#groupId")
    override fun getRanking(groupId: UUID): MutableList<RankingResponseDto> {
        return groupRepository.getRanking(groupId).map {
            RankingResponseDto(it[0] as UUID, it[1] as String, it[2] as Int, it[3] as Int?).also { e -> e.profileImageSmall = objectService.getObject(getUserFileProfileSmall(e.userId)) }
        }.toMutableList()
    }

    @Throws(EntityNotFoundException::class, UserNotFoundException::class)
    @Transactional
    @Caching(
        evict = [
            CacheEvict(value = ["userGroups"], key = "#userId"),
            CacheEvict(value = ["groupMembers"], key = "#groupId"),
            CacheEvict(value = ["isInGroup"], key = "{#groupId, #userId}"),
        ]
    )
    override fun deleteMember(userId: UUID, groupId: UUID) {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }

        val user = userRepository.findById(userId)
            .orElseThrow { UserNotFoundException("User does not exist") }

        if (user == group.groupAdmin && memberRepository.countByGroup(groupId) == 1L) {
            groupRepository.delete(group)
            log.info("Deleted group $groupId")
        } else if (user != group.groupAdmin) {
            memberRepository.deleteById_Group_IdAndId_User_Id(groupId, userId)
        } else {
            throw UserIsAdminException("User can not leave group as an admin")
        }

    }

    @Throws(UserNotFoundException::class)
    @Cacheable(value = ["userGroups"], key = "#userId")
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

    @Cacheable(value = ["isInGroup"], key = "{#group.id, #authentication.name}")
    override fun isInGroup(group: Group): Boolean {
        return memberRepository.existsById_Group_IdAndId_User_Id(group.id!!, UUID.fromString(SecurityContextHolder.getContext().authentication.name))
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}