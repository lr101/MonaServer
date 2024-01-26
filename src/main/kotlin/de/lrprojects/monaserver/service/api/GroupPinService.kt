package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import java.time.OffsetDateTime

interface GroupPinService {
    fun addPinToGroup(pinId: Long, groupId: Long)

    fun getPinsByGroup(groupId: Long, date: OffsetDateTime): List<Pin>

}