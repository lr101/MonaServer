package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.UserSeason
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface UserSeasonRepository : JpaRepository<UserSeason, UUID> {

}
