package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup
import java.util.*

interface GroupService {

    fun addGroup(createGroup: CreateGroup): Group
    fun deleteGroup(groupId: UUID)
    fun getGroup(groupId: UUID): de.lrprojects.monaserver.entity.Group
    fun getGroupAdmin(groupId: UUID): String
    fun getGroupDescription(groupId: UUID): String
    fun getGroupInviteUrl(groupId: UUID): String?
    fun getGroupLink(groupId: UUID): String?
    fun getGroupPinImage(groupId: UUID): ByteArray
    fun getGroupProfileImage(groupId: UUID): ByteArray
    fun getGroupsByIds(ids: List<UUID>?, search: String?, withUser: Boolean?, userId: UUID?): List<GroupSmall>
    fun updateGroup(groupId: UUID, updateGroup: UpdateGroup): Group
    fun getGroupOfPin(pinId: UUID):  de.lrprojects.monaserver.entity.Group
}