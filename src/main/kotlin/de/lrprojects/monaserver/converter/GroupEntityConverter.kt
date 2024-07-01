package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.GroupSmallDto
import de.lrprojects.monaserver.model.Visibility
import org.springframework.security.core.context.SecurityContextHolder
import java.time.ZoneOffset

fun Group.convertToGroupSmall(): GroupSmallDto {
    val groupSmall = GroupSmallDto(this.id, this.name, Visibility.fromValue(this.visibility))
    if (this.visibility == 0 || this.members.any { it.username == SecurityContextHolder.getContext().authentication.name }) {
        groupSmall.description = this.description
        groupSmall.inviteUrl = this.inviteUrl
        groupSmall.groupAdmin = this.groupAdmin?.id
        groupSmall.link = this.link
        groupSmall.lastUpdated = this.updateDate?.toInstant()?.atOffset(ZoneOffset.UTC)
    }
    return groupSmall
}

fun Group.toGroupModel() = GroupDto(
    this.id,
    this.description,
    this.inviteUrl,
    this.name,
    Visibility.fromValue(this.visibility),
    this.groupAdmin?.id,
    this.link,
    this.updateDate?.toInstant()?.atOffset(ZoneOffset.UTC)
)