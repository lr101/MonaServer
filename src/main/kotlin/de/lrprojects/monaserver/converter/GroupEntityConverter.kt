package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupDto
import de.lrprojects.monaserver.model.Visibility
import org.springframework.security.core.context.SecurityContextHolder
import java.util.*


fun Group.toGroupDto(withImages: Boolean? = true): GroupDto {
    val groupDto = GroupDto(this.id, this.name, Visibility.fromValue(this.visibility))
    if (withImages != null && withImages) {
        groupDto.also {
            it.profileImage = this.groupProfile
            it.pinImage = this.pinImage
        }
    }
    if (this.visibility == 0 || this.members.any { it.id == UUID.fromString(SecurityContextHolder.getContext().authentication.name) }) {
        groupDto.also {
            it.description = this.description
            it.groupAdmin = this.groupAdmin?.id
            it.link = this.link
            it.lastUpdated = this.updateDate
            it.inviteUrl = this.inviteUrl
        }
    }
    return groupDto
}