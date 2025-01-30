package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toGroupSeason
import de.lrprojects.monaserver.converter.toUserSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.repository.GroupSeasonRepository
import de.lrprojects.monaserver.repository.SeasonRepository
import de.lrprojects.monaserver.repository.UserSeasonRepository
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserver.service.api.UserService
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import kotlin.jvm.optionals.getOrNull

@Service
class SeasonServiceImpl (
    private val userSeasonRepository: UserSeasonRepository,
    private val groupSeasonRepository: GroupSeasonRepository,
    private val seasonRepository: SeasonRepository,
    private val rankingService: RankingService,
    private val userService: UserService,
    private val groupService: GroupService
): SeasonService {

    @Transactional
    override fun createSeason(month: Int, year: Int) {
        val seasonNumber = calculateSeasonNumber()

        val season = Season(
            seasonNumber = seasonNumber,
            year = year,
            month = month,
            creationDate = OffsetDateTime.now(),
            updateDate = OffsetDateTime.now()
        )

        seasonRepository.save(season)

        saveUserSeason(month, year, season)
        saveGroupSeason(month, year, season)
    }

    private fun calculateSeasonNumber(): Int {
        val lastSeason = seasonRepository.findTopByOrderBySeasonNumberDesc().getOrNull()
        return if (lastSeason == null) {
            1
        } else {
            lastSeason.seasonNumber + 1
        }
    }

    private fun saveUserSeason(month: Int, year: Int, season: Season) {
        val since = OffsetDateTime.of(year, month, 1, 0, 0, 0, 0, OffsetDateTime.now().offset)
        val ranking = rankingService.userRanking(null, null, null, since, Pageable.unpaged())
            .map { it.toUserSeason(userService, season) }.toSet()
        userSeasonRepository.saveAll(ranking)
    }

    private fun saveGroupSeason(month: Int, year: Int, season: Season) {
        val since = OffsetDateTime.of(year, month, 1, 0, 0, 0, 0, OffsetDateTime.now().offset)
        val ranking = rankingService.groupRanking(null, null, null, since, Pageable.unpaged())
            .map { it.toGroupSeason(groupService, season) }.toSet()
        groupSeasonRepository.saveAll(ranking)
    }

}
