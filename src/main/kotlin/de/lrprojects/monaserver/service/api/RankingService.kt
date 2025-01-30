package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Boundary
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.RankingSearchDtoInner
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.springframework.data.domain.Pageable
import java.time.OffsetDateTime

interface RankingService {

    fun getGeoJson(gid2: String): List<String>

    fun getMapInfo(latitude: Double?, longitude: Double?): MutableList<MapInfoDto>

    fun getBoundaryEntity(latitude: Double, longitude: Double): Boundary?

    fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        pageable: Pageable
    ): MutableList<GroupRankingDtoInner>


    fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        pageable: Pageable
    ): MutableList<UserRankingDtoInner>

    fun searchRanking(search: String?, pageable: Pageable): MutableList<RankingSearchDtoInner>
}