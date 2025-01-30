package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.entity.UserSeason
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import java.time.OffsetDateTime

fun UserRankingDtoInner.toUserSeason(userService: UserService, season: Season): UserSeason {
    val user = userService.getUser(this.userInfoDto.userId)
    user.updateDate = OffsetDateTime.now()
    return UserSeason(
        user = user,
        season = season,
        rank = this.rankNr,
        numberOfPins = this.points
    )
}

fun GroupRankingDtoInner.toGroupSeason(groupService: GroupService, season: Season): GroupSeason {
    val group =  groupService.getGroup(this.groupInfoDto.id)
    group.updateDate = OffsetDateTime.now()
    return GroupSeason(
        season = season,
        group = group,
        rank = this.rankNr,
        numberOfPins = this.points
    )
}