package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.config.ConstConfig
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserver.types.LevelType
import de.lrprojects.monaserver_api.model.UserInfoDto
import de.lrprojects.monaserver_api.model.UserXpDto


fun User.toUserInfoDto(seasonService: SeasonService) = UserInfoDto(this.username, this.id!!).also {
    it.description = this.description
    it.selectedBatch = this.selectedBatch?.achievementId
    it.bestSeason = seasonService.getBestUserSeason(this.id!!)
}

fun User.toXpDto() = UserXpDto().also {
    val level = LevelType.getLevel(this.xp)
    it.totalXp = this.xp
    it.currentLevel = level.level
    it.currentLevelXp = level.levelXp
    it.nextLevelXp = LevelType.getNextLevel(level.level).levelXp
}

fun User.setEmailConfirmationUrl() {
    this.emailConfirmationUrl = SecurityHelper.generateAlphabeticRandomString(ConstConfig.URL_VIW_LENGTH)
    this.emailConfirmed = false
}
