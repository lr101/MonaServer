package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver_api.model.PinRequestDto
import java.util.*

interface PinService {

    fun createPin(newPin: PinRequestDto): Pin
    fun deletePin(pinId: UUID)
    fun getPin(pinId: UUID): Pin

}