package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.GroupSeason
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface GroupSeasonRepository : JpaRepository<GroupSeason, UUID> {

}
