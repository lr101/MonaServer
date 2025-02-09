package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver_api.api.RankingApiDelegate
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.RankingSearchDtoInner
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component
import java.math.BigDecimal
import java.time.OffsetDateTime

@Component
class RankingController(
    private val rankingService: RankingService
) : RankingApiDelegate{

    override fun getGeoJson(gid2: String): ResponseEntity<List<String>> {
        log.info("Attempting to get geojson for gid2: $gid2")
        val result = rankingService.getGeoJson(gid2)
        log.info("Retrieved geojson for gid2: $gid2")
        return ResponseEntity.ok(result)
    }

    override fun getMapInfo(latitude: BigDecimal?, longitude: BigDecimal?): ResponseEntity<MutableList<MapInfoDto>> {
        log.info("Attempting to get map info with lat: $latitude, long: $longitude")
        val result = rankingService.getMapInfo(latitude?.toDouble(), longitude?.toDouble())
        log.info("Retrieved map info")
        return ResponseEntity.ok(result)
    }

    override fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<GroupRankingDtoInner>> {
        log.info("Attempting to get group ranking for gid0: $gid0, gid1: $gid1, gid2: $gid2, since: $since, season: $season")
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = rankingService.groupRanking(gid0, gid1, gid2, since, season, pageable)
        log.info("Retrieved group ranking")
        return ResponseEntity.ok(result)
    }


    override fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<UserRankingDtoInner>> {
        log.info("Attempting to get user ranking for gid0: $gid0, gid1: $gid1, gid2: $gid2, since: $since, season: $season")
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = rankingService.userRanking(gid0, gid1, gid2, since, season, pageable)
        log.info("Retrieved user ranking")
        return ResponseEntity.ok(result)
    }

    override fun searchRanking(
        search: String?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<RankingSearchDtoInner>> {
        log.info("Attempt to search for boundaries: $search")
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = rankingService.searchRanking(search, pageable)
        log.info("Successfully returns search results for boundaries")
        return ResponseEntity.ok(result)
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}