package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.GroupSeason
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface GroupSeasonRepository : JpaRepository<GroupSeason, UUID> {
    @Query(
        value = """
            SELECT us.* FROM groups_seasons us
            WHERE us.group_id = :groupId
            ORDER BY us.rank, us.number_of_pins DESC LIMIT 1
        """, nativeQuery = true
    )
    fun findBestSeasonOfGroup(@Param("groupId") groupId: UUID): GroupSeason?
}
