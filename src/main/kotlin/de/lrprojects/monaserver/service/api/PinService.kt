package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import org.openapitools.model.NewPin
import org.openapitools.model.PinInfo
import java.time.OffsetDateTime

interface PinService {


    fun getPinEntity(pinId: Long): Pin
    fun createPin(newPin: NewPin?): Pin
    fun deletePin(pinId: Long?): Void
    fun getPin(pinId: Long?): PinInfo
    fun getPinCreationUsername(pinId: Long?): String
    fun getPinsByGroup(groupId: Long?, date: OffsetDateTime?): MutableList<Pin>
    fun getPinsByIdsAndUsername(username: String?, ids: MutableList<Long>?): MutableList<Pin>
    fun getPinsByUsername(username: String?): MutableList<Pin>
    fun getPinsByUsernameAndGroup(username: String?, groupId: Long?): MutableList<Pin>

}