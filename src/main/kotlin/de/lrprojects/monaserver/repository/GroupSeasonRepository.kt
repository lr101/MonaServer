package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.UserSeason
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
            ORDER BY us.rank DESC LIMIT 1
        """, nativeQuery = true
    )
    fun findBestSeasonOfGroup(@Param("groupId") groupId: UUID): GroupSeason?
}
