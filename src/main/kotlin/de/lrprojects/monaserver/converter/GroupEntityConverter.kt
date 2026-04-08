package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getGroupFilePin
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getGroupFileProfile
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getGroupFileProfileSmall
import de.lrprojects.monaserverapi.model.GroupDto
import de.lrprojects.monaserverapi.model.SeasonItemDto
import org.springframework.security.core.context.SecurityContextHolder
import java.util.*


fun Group.toGroupDto(
    memberService: MemberService,
    withImages: Boolean? = true,
    objectService: ObjectService,
    seasonItemDto: SeasonItemDto?
): GroupDto {
    val withImage = withImages != null && withImages
    val visibleToUser = this.visibility == 0 || memberService.isInGroup(this, UUID.fromString(SecurityContextHolder.getContext().authentication?.name))
    val groupDto = GroupDto(
        this.id!!,
        this.name!!,
        this.visibility,
        profileImage = if (withImage) objectService.getObject(getGroupFileProfile(id!!)) else null,
        pinImage = if (withImage) objectService.getObject(getGroupFilePin(id!!)) else null,
        profileImageSmall = if (withImage) objectService.getObject(getGroupFileProfileSmall(id!!)) else null,
        description = if (visibleToUser) this.description else null,
        groupAdmin = if (visibleToUser) this.groupAdmin!!.id else null,
        link = if (visibleToUser) this.link else null,
        lastUpdated = if (visibleToUser) this.updateDate else null,
        inviteUrl = if (visibleToUser) this.inviteUrl else null,
        bestSeason = seasonItemDto
    )
    return groupDto
}