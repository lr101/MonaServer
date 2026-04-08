package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserverapi.model.PinRequestDto

interface GroupPinService {
    fun addPinToGroup(newPin: PinRequestDto) : Pin

}