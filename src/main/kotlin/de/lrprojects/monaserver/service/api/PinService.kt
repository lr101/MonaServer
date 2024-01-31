package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.PinInfo
import java.time.OffsetDateTime

interface PinService {

    fun createPin(newPin: NewPin): Pin
    fun deletePin(pinId: Long)
    fun getPin(pinId: Long): PinInfo
    fun getPinCreationUsername(pinId: Long): String
    fun getPinsByGroup(currentUsername: String, groupId: Long, date: OffsetDateTime): MutableList<Pin>
    fun getPinsByIdsAndUsername(currentUsername: String, username: String, ids: MutableList<Long>): MutableList<Pin>
    fun getPinsByUsername(currentUsername: String, username: String): MutableList<Pair<Pin, Long>>
    fun getPinsByUsernameAndGroup(currentUsername: String, username: String, groupId: Long): MutableList<Pin>

}