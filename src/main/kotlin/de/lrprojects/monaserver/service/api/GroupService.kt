package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver_api.model.CreateGroupDto
import de.lrprojects.monaserver_api.model.UpdateGroupDto
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import java.time.OffsetDateTime
import java.util.*

interface GroupService {

    fun addGroup(createGroup: CreateGroupDto): Group
    fun deleteGroup(groupId: UUID)
    fun getGroup(groupId: UUID): Group
    fun getGroupAdmin(groupId: UUID): String
    fun getGroupDescription(groupId: UUID): String
    fun getGroupInviteUrl(groupId: UUID): String?
    fun getGroupLink(groupId: UUID): String?
    fun getGroupPinImage(groupId: UUID): ByteArray
    fun getGroupProfileImage(groupId: UUID): ByteArray
    fun getGroupsByIds(ids: List<UUID>?, search: String?, withUser: Boolean?, userId: UUID?, updatedAfter: OffsetDateTime?, pageable: Pageable): Page<Group>
    fun updateGroup(groupId: UUID, updateGroup: UpdateGroupDto): Group
    fun getGroupOfPin(pinId: UUID):  Group
}