package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver_api.api.RankingApiDelegate
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component
import java.math.BigDecimal

@Component
class RankingController(
    private val rankingService: RankingService
) : RankingApiDelegate{

    override fun getGeoJson(gid2: String): ResponseEntity<List<String>> {
        val result = rankingService.getGeoJson(gid2)
        return ResponseEntity.ok(result)
    }

    override fun getMapInfo(latitude: BigDecimal?, longitude: BigDecimal?): ResponseEntity<MutableList<MapInfoDto>> {
        val result = rankingService.getMapInfo(latitude?.toDouble(), longitude?.toDouble())
        return ResponseEntity.ok(result)
    }

    override fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<GroupRankingDtoInner>> {
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = rankingService.groupRanking(gid0, gid1, gid2, pageable)
        return ResponseEntity.ok(result)
    }


    override fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        page: Int?,
        size: Int
    ): ResponseEntity<MutableList<UserRankingDtoInner>> {
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val result = rankingService.userRanking(gid0, gid1, gid2, pageable)
        return ResponseEntity.ok(result)
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}