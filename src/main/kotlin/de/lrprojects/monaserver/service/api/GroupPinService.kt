package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin
import org.openapitools.model.NewPin

interface GroupPinService {
    fun addPinToGroup(newPin: NewPin) : Pin

}