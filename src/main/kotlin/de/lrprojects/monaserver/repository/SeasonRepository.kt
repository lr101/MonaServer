package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Season
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface SeasonRepository : JpaRepository<Season, UUID> {


    fun findTopByOrderBySeasonNumberDesc(): Optional<Season>
}
