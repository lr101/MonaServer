package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toMapInfoDto
import de.lrprojects.monaserver.entity.Boundary
import de.lrprojects.monaserver.excepetion.AssertException
import de.lrprojects.monaserver.repository.BoundaryRepository
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver_api.model.GroupDto
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.RankingSearchDtoInner
import de.lrprojects.monaserver_api.model.UserInfoDto
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import java.time.OffsetDateTime
import java.util.*


@Service
class RankingServiceImpl(
    private val boundaryRepository: BoundaryRepository
): RankingService {

    override fun getGeoJson(gid2: String): List<String> {
            return boundaryRepository.getGeoJsonFromGid(gid2)
    }

    override fun getMapInfo(latitude: Double?, longitude: Double?): MutableList<MapInfoDto> {
        if (latitude != null && longitude != null) {
            val boundary = boundaryRepository.getBoundaryOrClosest(latitude, longitude)
            return boundary?.let {  mutableListOf(boundary.toMapInfoDto()) } ?: mutableListOf()
        } else {
            throw AssertException("Both latitude and longitude must be set")
        }
    }

    override fun getBoundaryEntity(latitude: Double, longitude: Double): Boundary? {
        return boundaryRepository.getBoundaryOrClosest(latitude, longitude)
    }

    override fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        pageable: Pageable
    ): MutableList<GroupRankingDtoInner> {
        var rank = if(pageable.isPaged)  pageable.pageNumber * pageable.pageSize else 0
        return boundaryRepository.getGroupRanking(gid0, gid1, gid2, getSinceValue(since, season), pageable).map { r ->
            rank += 1
            GroupRankingDtoInner().also {
                it.rankNr = rank
                it.points = r[4] as Int
                it.groupInfoDto = GroupDto(r[0] as UUID, r[1] as String, r[2] as Int).also {
                    g -> g.description = if(r[2] == 0) r[3] as String? else null
                }
            }
        }.toMutableList()
    }

    override fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        since: OffsetDateTime?,
        season: Boolean?,
        pageable: Pageable
    ): MutableList<UserRankingDtoInner> {
        var rank = if(pageable.isPaged)  pageable.pageNumber * pageable.pageSize else 0
        return boundaryRepository.getUserRanking(gid0, gid1, gid2, getSinceValue(since, season), pageable).map { r ->
            rank += 1
            UserRankingDtoInner().also {
                it.rankNr = rank
                it.points = r[3] as Int
                it.userInfoDto = UserInfoDto(r[1] as String, r[0] as UUID).also { user ->
                    user.description = r[2] as String?
                    user.selectedBatch = r[4] as Int?
                }
            }
        }.toMutableList()
    }

    private fun getSinceValue(since: OffsetDateTime?, season: Boolean?): OffsetDateTime? {
        return since
            ?: if (season == true) {
                val now = OffsetDateTime.now()
                OffsetDateTime.of(now.year, now.monthValue, 0, 0, 0, 0, 0, now.offset)
            } else {
                null
            }
    }

    override fun searchRanking(search: String?, pageable: Pageable): MutableList<RankingSearchDtoInner> {
        return boundaryRepository.searchBoundaries(search, pageable).map { r ->
            RankingSearchDtoInner(r[0] as Int, r[2] as String?, r[1] as String?)
        }.toMutableList()
    }
}