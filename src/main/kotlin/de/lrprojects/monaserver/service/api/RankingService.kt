package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.springframework.data.domain.Pageable

interface RankingService {

    fun getGeoJson(gid0: String): List<String>

    fun getMapInfo(latitude: Double?, longitude: Double?): MutableList<MapInfoDto>

    fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        pageable: Pageable
    ): MutableList<GroupRankingDtoInner>


    fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        pageable: Pageable
    ): MutableList<UserRankingDtoInner>
}