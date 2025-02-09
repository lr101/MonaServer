package de.lrprojects.monaserver.schedular

import de.lrprojects.monaserver.service.api.SeasonService
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.LocalDate


@Service
class SeasonScheduler (
    private val seasonService: SeasonService
) {

    @Scheduled(cron = "0 59 23 L * ?")
    fun generateSeasonResults() {
        val now = LocalDate.now()
        val month = now.monthValue
        val year = now.year

        seasonService.createSeason(month, year)
    }
}
