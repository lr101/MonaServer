package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.PinInfo
import de.lrprojects.monaserver.model.UserInfo
import java.time.OffsetDateTime
import java.util.*

interface PinService {

    fun createPin(newPin: NewPin): Pin
    fun deletePin(pinId: UUID)
    fun getPin(pinId: UUID): Pin
    fun getPinCreationUsername(pinId: UUID): UserInfo
    fun getPinsByGroup(currentUserId: UUID, groupId: UUID, date: OffsetDateTime): MutableList<Pin>
    fun getPinsByIdsAndUsername(currentUserId: UUID, userId: UUID, ids: MutableList<UUID>): MutableList<Pin>
    fun getPinsByUsernameAndGroup(currentUserId: UUID, userId: UUID, groupId: UUID): MutableList<Pin>

}