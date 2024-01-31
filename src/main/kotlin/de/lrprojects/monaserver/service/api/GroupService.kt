package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.CreateGroup
import de.lrprojects.monaserver.model.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.UpdateGroup

interface GroupService {

    fun addGroup(createGroup: CreateGroup): Group
    fun deleteGroup(groupId: Long)
    fun getGroup(groupId: Long): GroupSmall
    fun getGroupAdmin(groupId: Long): String
    fun getGroupDescription(groupId: Long): String
    fun getGroupIdsBySearchTerm(search: String, withUser: Boolean): List<Long>
    fun getGroupInviteUrl(groupId: Long): String?
    fun getGroupLink(groupId: Long): String?
    fun getGroupPinImage(groupId: Long): ByteArray
    fun getGroupProfileImage(groupId: Long): ByteArray
    fun getGroupsByIds(ids: List<Long>): List<GroupSmall>
    fun updateGroup(groupId: Long, updateGroup: UpdateGroup): Group
}