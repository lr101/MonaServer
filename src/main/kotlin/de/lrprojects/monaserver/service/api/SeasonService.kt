package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver_api.model.SeasonItemDto
import java.util.*

interface SeasonService {
    fun createSeason(month: Int, year: Int)
    fun getBestGroupSeason(groupId: UUID): SeasonItemDto?
    fun getBestUserSeason(userId: UUID): SeasonItemDto?
}