package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toGroupSeason
import de.lrprojects.monaserver.converter.toSeasonItemDto
import de.lrprojects.monaserver.converter.toUserSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.GroupSeasonRepository
import de.lrprojects.monaserver.repository.SeasonRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.repository.UserSeasonRepository
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserver_api.model.SeasonItemDto
import org.slf4j.LoggerFactory
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*
import kotlin.jvm.optionals.getOrNull

@Service
class SeasonServiceImpl (
    private val userSeasonRepository: UserSeasonRepository,
    private val groupSeasonRepository: GroupSeasonRepository,
    private val seasonRepository: SeasonRepository,
    private val rankingService: RankingService,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository
): SeasonService {

    @Transactional
    override fun createSeason(month: Int, year: Int) {
        log.info("Creating season for month: $month, year: $year")
        val seasonNumber = calculateSeasonNumber()

        var season = Season(
            seasonNumber = seasonNumber,
            year = year,
            month = month
        )

        season = seasonRepository.save(season)

        saveUserSeason(month, year, season)
        saveGroupSeason(month, year, season)
        log.info("Created season for month: $month, year: $year with season number: $seasonNumber")
    }

    override fun getBestGroupSeason(groupId: UUID): SeasonItemDto? {
        return groupSeasonRepository.findBestSeasonOfGroup(groupId)?.toSeasonItemDto()
    }

    override fun getBestUserSeason(userId: UUID): SeasonItemDto? {
        return userSeasonRepository.findBestSeasonOfUser(userId)?.toSeasonItemDto()
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
        val ranking = rankingService.userRanking(null, null, null, since, null, Pageable.unpaged())
            .map { it.toUserSeason(userRepository, season) }.toSet()
        userSeasonRepository.saveAll(ranking)
    }

    private fun saveGroupSeason(month: Int, year: Int, season: Season) {
        val since = OffsetDateTime.of(year, month, 1, 0, 0, 0, 0, OffsetDateTime.now().offset)
        val ranking = rankingService.groupRanking(null, null, null, since, null, Pageable.unpaged())
            .map { it.toGroupSeason(groupRepository, season) }.toSet()
        groupSeasonRepository.saveAll(ranking)
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}
