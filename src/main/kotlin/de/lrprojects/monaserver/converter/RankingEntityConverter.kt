package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.entity.UserSeason
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.UserRankingDtoInner

fun UserRankingDtoInner.toUserSeason(userService: UserService, season: Season) = UserSeason(
    user = userService.getUser(this.userInfoDto.userId),
    season = season,
    rank = this.rankNr,
    numberOfPins = this.points
)

fun GroupRankingDtoInner.toGroupSeason(groupService: GroupService, season: Season) = GroupSeason(
    season = season,
    group = groupService.getGroup(this.groupInfoDto.id),
    rank = this.rankNr,
    numberOfPins = this.points
)