package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.excepetion.AssertException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver_api.model.*
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.MemberService
import jakarta.persistence.EntityNotFoundException
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.sql.SQLException
import java.time.OffsetDateTime
import java.util.*
import kotlin.jvm.optionals.getOrElse

@Service
class GroupServiceImpl (
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val imageHelper: ImageHelper,
    private val memberService: MemberService
) : GroupService {

    @Transactional
    override fun addGroup(createGroup: CreateGroupDto): Group {
        val group = Group()
        group.groupAdmin = userRepository.findById(createGroup.groupAdmin).getOrElse { throw UserNotFoundException("Admin not found") }
        group.visibility = createGroup.visibility
        group.description = createGroup.description
        group.name = createGroup.name
        group.link = createGroup.link
        group.pinImage = imageHelper.getPinImage(createGroup.profileImage)
        group.groupProfile = imageHelper.getProfileImage(createGroup.profileImage)
        if (group.visibility == 1) {
            group.inviteUrl = SecurityHelper.generateAlphabeticRandomString(6)
        }
        val g =  groupRepository.save(group)

        memberService.addMember(userId = g.groupAdmin!!.id!!, groupId = g.id!!, inviteUrl = g.inviteUrl)
        return g
    }

    @Throws(SQLException::class)
    @Transactional
    override fun deleteGroup(groupId: UUID) {
        groupRepository.deleteById(groupId)

    }

    @Throws(EntityNotFoundException::class)
    override fun getGroup(groupId: UUID): Group {
        return  groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
    }

    @Throws(EntityNotFoundException::class)
    override fun getGroupAdmin(groupId: UUID): String {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.groupAdmin?.username ?: throw EntityNotFoundException("Admin not found")
    }

    @Throws(EntityNotFoundException::class)
    override fun getGroupDescription(groupId: UUID): String {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.description.orEmpty()
    }

    override fun getGroupInviteUrl(groupId: UUID): String? {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.inviteUrl
    }

    override fun getGroupLink(groupId: UUID): String? {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.link
    }

    override fun getGroupPinImage(groupId: UUID): ByteArray {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.pinImage!!
    }

    override fun getGroupProfileImage(groupId: UUID): ByteArray {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.groupProfile!!
    }

    override fun getGroupsByIds(ids: List<UUID>?, search: String?, withUser: Boolean?, userId: UUID?, updatedAfter: OffsetDateTime?, pageable: Pageable): Page<Group> {
        if ((withUser != null && userId == null) || (withUser == null && userId != null)) throw AssertException("A username must be set when withUser is used")
        return when (withUser) {
            null -> groupRepository.searchGroups(ids?.toTypedArray(), search, updatedAfter, pageable)
            true -> groupRepository.searchInUserGroup(userId!!, search, ids?.toTypedArray(), updatedAfter, pageable)
            false -> groupRepository.searchInNotUserGroup(userId!!, search, ids?.toTypedArray(), updatedAfter, pageable)
        }
    }



    @Throws(EntityNotFoundException::class, UserNotFoundException::class)
    override fun updateGroup(groupId: UUID, updateGroup: UpdateGroupDto): Group {
        var group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        updateGroup.name?.let { group.name = updateGroup.name }
        updateGroup.description?.let { group.description = updateGroup.description }
        updateGroup.link?.let { group.link = updateGroup.link }
        updateGroup.profileImage?.let { group.groupProfile = imageHelper.getProfileImage(it) }
        updateGroup.profileImage?.let { group.pinImage = imageHelper.getPinImage(it) }
        updateGroup.visibility?.let { group.visibility = updateGroup.visibility }
        if (updateGroup.visibility!! == 0) {
            group.inviteUrl = null
        } else {
            group.setInvite()
        }
        updateGroup.groupAdmin?.let { adminId ->
            group.groupAdmin =userRepository.findById(adminId).getOrElse { throw UserNotFoundException("Admin does not exist") }
        }
        return groupRepository.save(group)
    }

    override fun getGroupOfPin(pinId: UUID): Group {
        return groupRepository.findByPinId(pinId)
    }
}