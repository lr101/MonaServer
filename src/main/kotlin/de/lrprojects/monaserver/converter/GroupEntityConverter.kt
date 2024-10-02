package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.model.GroupDto
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
        profileImage = if (withImage) this.groupProfile else null,
        pinImage = if (withImage) this.pinImage else null,
        description = if (visibleToUser) this.description else null,
        groupAdmin = if (visibleToUser) this.groupAdmin!!.id else null,
        link = if (visibleToUser) this.link else null,
        lastUpdated = if (visibleToUser) this.updateDate else null,
        inviteUrl = if (visibleToUser) this.inviteUrl else null,
    )
    return groupDto
}