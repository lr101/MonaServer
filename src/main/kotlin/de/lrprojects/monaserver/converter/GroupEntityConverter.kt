package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver_api.model.GroupDto
import de.lrprojects.monaserver.service.api.MemberService
import org.springframework.security.core.context.SecurityContextHolder
import java.util.*


fun Group.toGroupDto(memberService: MemberService, withImages: Boolean? = true): GroupDto {
    val withImage = withImages != null && withImages
    val visibleToUser = this.visibility == 0 || memberService.getMembers(this.id!!).any { it.userId == UUID.fromString(SecurityContextHolder.getContext().authentication.name) }
    val groupDto = GroupDto(
        this.id!!,
        this.name!!,
        this.visibility,
    ).also {
        it.profileImage = if (withImage) this.groupProfile else null
        it.pinImage = if (withImage) this.pinImage else null
        it.description = if (visibleToUser) this.description else null
        it.groupAdmin = if (visibleToUser) this.groupAdmin!!.id else null
        it.link = if (visibleToUser) this.link else null
        it.lastUpdated = if (visibleToUser) this.updateDate else null
        it.inviteUrl = if (visibleToUser) this.inviteUrl else null
    }
    return groupDto
}