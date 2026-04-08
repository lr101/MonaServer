package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.config.ConstConfig
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserver.types.LevelType
import de.lrprojects.monaserverapi.model.UserInfoDto
import de.lrprojects.monaserverapi.model.UserXpDto
import org.springframework.security.core.context.SecurityContextHolder


fun User.toUserInfoDto(seasonService: SeasonService) = UserInfoDto(
    this.username,
    this.id!!,
    description = this.description,
    selectedBatch = this.selectedBatch?.achievementId,
    bestSeason = seasonService.getBestUserSeason(this.id!!),
    isMessagingRegistered = if(SecurityContextHolder.getContext().authentication?.name == this.id.toString()) this.firebaseToken != null else false
)

fun User.toXpDto(): UserXpDto {
    val level = LevelType.getLevel(this.xp)
    return UserXpDto(
        totalXp = this.xp,
        currentLevel = level.level,
        currentLevelXp = level.levelXp,
        nextLevelXp = LevelType.getNextLevel(level.level).levelXp
    )
}

fun User.setEmailConfirmationUrl() {
    this.emailConfirmationUrl = SecurityHelper.generateAlphabeticRandomString(ConstConfig.URL_VIW_LENGTH)
    this.emailConfirmed = false
}
