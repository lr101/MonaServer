package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinRequestDto
import java.time.OffsetDateTime
import java.util.*

interface PinService {

    fun createPin(newPin: PinRequestDto): Pin
    fun deletePin(pinId: UUID)
    fun getPin(pinId: UUID): Pin
    fun getPinsByGroup(currentUserId: UUID, groupId: UUID, date: OffsetDateTime): MutableList<Pin>
    fun getPinsByIdsAndUsername(currentUserId: UUID, userId: UUID, ids: MutableList<UUID>): MutableList<Pin>
    fun getPinsByUsernameAndGroup(currentUserId: UUID, userId: UUID, groupId: UUID): MutableList<Pin>

}