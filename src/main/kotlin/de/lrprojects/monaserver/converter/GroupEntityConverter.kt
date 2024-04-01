package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.Visibility
import org.springframework.security.core.context.SecurityContextHolder
import java.time.ZoneOffset

fun Group.convertToGroupSmall(): GroupSmall {
    val groupSmall = GroupSmall(this.id, this.name, Visibility.fromValue(this.visibility))
    if (this.visibility == 0 || this.members.any { it.username == SecurityContextHolder.getContext().authentication.name }) {
        groupSmall.description = this.description
        groupSmall.inviteUrl = this.inviteUrl
        groupSmall.groupAdmin = this.groupAdmin?.id
        groupSmall.link = this.link
        groupSmall.lastUpdated = this.updateDate?.toInstant()?.atOffset(ZoneOffset.UTC)
    }
    return groupSmall
}

fun Group.toGroupModel() = de.lrprojects.monaserver.model.Group(
    this.id,
    this.description,
    this.inviteUrl,
    this.name,
    Visibility.fromValue(this.visibility),
    this.groupAdmin?.id,
    this.link,
    this.updateDate?.toInstant()?.atOffset(ZoneOffset.UTC)
)