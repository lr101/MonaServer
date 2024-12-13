package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.UserAchievement
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface AchievementRepository : JpaRepository<UserAchievement, UUID> {

    fun findByUser_IdAndAchievementId(userIid: UUID, achievementId: Int): Optional<UserAchievement>

    fun findByUser_IdAndClaimedIsTrue(userId: UUID): List<UserAchievement>



}