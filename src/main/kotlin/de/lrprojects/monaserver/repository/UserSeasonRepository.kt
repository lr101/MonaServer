package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.UserSeason
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface UserSeasonRepository : JpaRepository<UserSeason, UUID> {


    @Query(
        value = """
            SELECT us.* FROM users_seasons us
            WHERE us.user_id = :userId
            ORDER BY us.rank DESC LIMIT 1
        """, nativeQuery = true
    )
    fun findBestSeasonOfUser(@Param("userId") userId: UUID): UserSeason?
}
