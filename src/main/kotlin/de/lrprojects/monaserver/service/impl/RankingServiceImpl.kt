package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toMapInfoDto
import de.lrprojects.monaserver.entity.Boundary
import de.lrprojects.monaserver.excepetion.AssertException
import de.lrprojects.monaserver.repository.BoundaryRepository
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver_api.model.GroupDto
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.MapInfoDto
import de.lrprojects.monaserver_api.model.UserInfoDto
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.springframework.cache.annotation.Cacheable
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import java.util.*


@Service
class RankingServiceImpl(
    private val boundaryRepository: BoundaryRepository
): RankingService {

    @Cacheable(value = ["geojson"], key = "#gid2")
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

    @Cacheable(value = ["groupRanking"], key = "{#gid0, #gid1, #gid2, #pageable.pageNumber, #pageable.pageSize}")
    override fun groupRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        pageable: Pageable
    ): MutableList<GroupRankingDtoInner> {
        var rank = if(pageable.isPaged)  pageable.pageNumber * pageable.pageSize else 0
        return boundaryRepository.getGroupRanking(gid0, gid1, gid2, pageable).map { r ->
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

    @Cacheable(value = ["userRanking"], key = "{#gid0, #gid1, #gid2, #pageable.pageNumber, #pageable.pageSize}")
    override fun userRanking(
        gid0: String?,
        gid1: String?,
        gid2: String?,
        pageable: Pageable
    ): MutableList<UserRankingDtoInner> {
        var rank = if(pageable.isPaged)  pageable.pageNumber * pageable.pageSize else 0
        return boundaryRepository.getUserRanking(gid0, gid1, gid2, pageable).map { r ->
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
}