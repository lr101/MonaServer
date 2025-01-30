package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.entity.UserSeason
import de.lrprojects.monaserver_api.model.SeasonDto
import de.lrprojects.monaserver_api.model.SeasonItemDto

fun Season.toSeasonDto() = SeasonDto(
    this.id,
    this.month,
    this.year,
    this.seasonNumber
)

fun UserSeason.toSeasonItemDto() = SeasonItemDto(
    this.id,
    this.season.toSeasonDto(),
    this.numberOfPins,
    this.rank
)

fun GroupSeason.toSeasonItemDto() = SeasonItemDto(
    this.id,
    this.season.toSeasonDto(),
    this.numberOfPins,
    this.rank
)
