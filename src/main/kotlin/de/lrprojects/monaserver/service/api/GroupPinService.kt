package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver_api.model.PinRequestDto

interface GroupPinService {
    fun addPinToGroup(newPin: PinRequestDto) : Pin

}