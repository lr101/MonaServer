package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver_api.model.PinRequestDto
import java.util.*

interface PinService {

    fun createPin(newPin: PinRequestDto): Pin
    fun deletePin(pinId: UUID)
    fun deleteObjectsByList(pinIds: List<UUID>)
    fun getPin(pinId: UUID): Pin
    fun getGroupPins(group: Group): List<UUID>
    fun getUserPins(user: User): List<UUID>

}