package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.entity.UserSeason
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver_api.model.GroupRankingDtoInner
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import jakarta.persistence.EntityNotFoundException
import java.time.OffsetDateTime

fun UserRankingDtoInner.toUserSeason(userRepository: UserRepository, season: Season): UserSeason {
    val user = userRepository.findById(this.userInfoDto.userId)
        .orElseThrow { EntityNotFoundException("user not found") }
    user.updateDate = OffsetDateTime.now()
    return UserSeason(
        user = user,
        season = season,
        rank = this.rankNr,
        numberOfPins = this.points
    )
}

fun GroupRankingDtoInner.toGroupSeason(groupRepository: GroupRepository, season: Season): GroupSeason {
    val group =  groupRepository.findById(this.groupInfoDto.id)
        .orElseThrow { EntityNotFoundException("group not found") }
    group.updateDate = OffsetDateTime.now()
    return GroupSeason(
        season = season,
        group = group,
        rank = this.rankNr,
        numberOfPins = this.points
    )
}