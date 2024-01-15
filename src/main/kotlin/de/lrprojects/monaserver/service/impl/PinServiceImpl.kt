package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.service.api.PinService
import org.openapitools.model.NewPin
import org.openapitools.model.PinInfo
import java.time.OffsetDateTime

class PinServiceImpl : PinService {
    override fun createPin(newPin: NewPin?): Pin {
        TODO("Not yet implemented")
    }

    override fun deletePin(pinId: Long?): Void {
        TODO("Not yet implemented")
    }

    override fun getPin(pinId: Long?): PinInfo {
        TODO("Not yet implemented")
    }

    override fun getPinCreationUsername(pinId: Long?): String {
        TODO("Not yet implemented")
    }

    override fun getPinsByGroup(groupId: Long?, date: OffsetDateTime?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByIdsAndUsername(username: String?, ids: MutableList<Long>?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsername(username: String?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsernameAndGroup(username: String?, groupId: Long?): MutableList<Pin> {
        TODO("Not yet implemented")
    }
}