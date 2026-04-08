package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserverapi.model.UserAchievementsDtoInner
import java.util.*

interface AchievementService {

    fun claimAchievement(userId: UUID, achievementId: Int)

    fun getAchievement(userId: UUID): MutableList<UserAchievementsDtoInner>
}