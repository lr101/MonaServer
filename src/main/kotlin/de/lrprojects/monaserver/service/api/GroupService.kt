package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.CreateGroupDto
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.GroupSmallDto
import de.lrprojects.monaserver.model.UpdateGroupDto
import java.util.*

interface GroupService {

    fun addGroup(createGroup: CreateGroupDto): GroupDto
    fun deleteGroup(groupId: UUID)
    fun getGroup(groupId: UUID): de.lrprojects.monaserver.entity.Group
    fun getGroupAdmin(groupId: UUID): String
    fun getGroupDescription(groupId: UUID): String
    fun getGroupInviteUrl(groupId: UUID): String?
    fun getGroupLink(groupId: UUID): String?
    fun getGroupPinImage(groupId: UUID): ByteArray
    fun getGroupProfileImage(groupId: UUID): ByteArray
    fun getGroupsByIds(ids: List<UUID>?, search: String?, withUser: Boolean?, userId: UUID?): List<GroupSmallDto>
    fun updateGroup(groupId: UUID, updateGroup: UpdateGroupDto): GroupDto
    fun getGroupOfPin(pinId: UUID):  de.lrprojects.monaserver.entity.Group
}