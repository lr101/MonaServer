package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Pin

interface GroupPinService {
    fun addPinToGroup(pinId: Long, groupId: Long)

}