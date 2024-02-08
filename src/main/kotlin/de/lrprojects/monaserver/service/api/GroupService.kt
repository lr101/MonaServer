package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup

interface GroupService {

    fun addGroup(createGroup: CreateGroup): Group
    fun deleteGroup(groupId: Long)
    fun getGroup(groupId: Long): de.lrprojects.monaserver.entity.Group
    fun getGroupAdmin(groupId: Long): String
    fun getGroupDescription(groupId: Long): String
    fun getGroupInviteUrl(groupId: Long): String?
    fun getGroupLink(groupId: Long): String?
    fun getGroupPinImage(groupId: Long): ByteArray
    fun getGroupProfileImage(groupId: Long): ByteArray
    fun getGroupsByIds(ids: List<Long>?, search: String?, withUser: Boolean?, username: String?): List<GroupSmall>
    fun updateGroup(groupId: Long, updateGroup: UpdateGroup): Group
    fun getGroupOfPin(pinId: Long):  de.lrprojects.monaserver.entity.Group
}