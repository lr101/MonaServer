package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.convertToGroupSmall
import de.lrprojects.monaserver.converter.toGroupModel
import de.lrprojects.monaserver.dto.toSmallGroup
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.model.*
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.GroupService
import jakarta.persistence.EntityNotFoundException
import de.lrprojects.monaserver.repository.PinRepository
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.sql.SQLException
import kotlin.jvm.optionals.getOrElse

@Service
@Transactional
class GroupServiceImpl (
    @Autowired val userRepository: UserRepository,
    @Autowired val groupRepository: GroupRepository,
    @Autowired val imageHelper: ImageHelper,
    @Autowired val pinRepository: PinRepository
) : GroupService {

    override fun addGroup(createGroup: CreateGroup): Group {
        var group = de.lrprojects.monaserver.entity.Group()
        group.groupAdmin = userRepository.findById(createGroup.groupAdmin).getOrElse {throw UserNotFoundException("User as admin does not exist")}
        group.visibility = createGroup.visibility.value
        group.description = createGroup.description
        group.name = createGroup.name
        group.members.add(group.groupAdmin!!)
        group.link = createGroup.link
        group.pinImage = imageHelper.getPinImage(createGroup.profileImage)
        group.profileImage = imageHelper.getProfileImage(createGroup.profileImage)
        if (group.visibility == 1) {
            group.inviteUrl = SecurityHelper.generateAlphabeticRandomString(6)
        }
        group = groupRepository.save(group)
        return group.toGroupModel()
    }

    @Throws(SQLException::class)
    override fun deleteGroup(groupId: Long) {
        groupRepository.deleteById(groupId)
    }

    @Throws(EntityNotFoundException::class)
    override fun getGroup(groupId: Long): GroupSmall {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.convertToGroupSmall()
    }

    @Throws(EntityNotFoundException::class)
    override fun getGroupAdmin(groupId: Long): String {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.groupAdmin?.username ?: throw EntityNotFoundException("Admin not found")
    }

    @Throws(EntityNotFoundException::class)
    override fun getGroupDescription(groupId: Long): String {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.description.orEmpty()
    }

    override fun getGroupInviteUrl(groupId: Long): String? {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.inviteUrl
    }

    override fun getGroupLink(groupId: Long): String? {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.link
    }

    override fun getGroupPinImage(groupId: Long): ByteArray {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.pinImage!!
    }

    override fun getGroupProfileImage(groupId: Long): ByteArray {
        val group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        return group.profileImage!!
    }

    override fun getGroupsByIds(ids: List<Long>?, search: String?, withUser: Boolean?, username: String?): List<GroupSmall> {
        if ((withUser != null && username == null) || (withUser == null && username != null)) throw AssertionError("A username must be set when withUser is used")
        return when (withUser) {
            null -> groupRepository.searchGroups(
                ids?.toTypedArray(), search).map { r -> r.convertToGroupSmall() }
            true -> groupRepository.searchInUserGroup(username!!, search,
                ids?.toTypedArray()).map { r -> r.convertToGroupSmall() }
            false -> groupRepository.searchInNotUserGroup(username!!, search,
                ids?.toTypedArray()).map { r -> r.convertToGroupSmall() }
        }
    }



    @Throws(EntityNotFoundException::class, UserNotFoundException::class)
    override fun updateGroup(groupId: Long, updateGroup: UpdateGroup): Group {
        var group = groupRepository.findById(groupId)
            .orElseThrow { EntityNotFoundException("Group not found") }
        updateGroup.name?.let { group.name = updateGroup.name }
        updateGroup.description?.let { group.description = updateGroup.description }
        updateGroup.link?.let { group.link = updateGroup.link }
        updateGroup.profileImage?.let { group.profileImage = imageHelper.getProfileImage(it) }
        updateGroup.profileImage?.let { group.pinImage = imageHelper.getPinImage(it) }
        updateGroup.visibility?.let { group.visibility = updateGroup.visibility.value }
        if (updateGroup.visibility.value == 0) {
            group.inviteUrl = null
        } else {
            group.setInvite()
        }
        updateGroup.groupAdmin?.let { adminId ->
            userRepository.findById(adminId).getOrElse { throw UserNotFoundException("Admin does not exist") }
        }
        group = groupRepository.save(group)
        return group.toGroupModel()
    }

    override fun getGroupOfPin(pinId: Long): de.lrprojects.monaserver.entity.Group {
        return groupRepository.findByPin(pinId)
    }
}