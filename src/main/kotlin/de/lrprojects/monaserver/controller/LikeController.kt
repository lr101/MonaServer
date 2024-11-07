package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.LikesApiDelegate
import de.lrprojects.monaserver.model.CreateLikeDto
import de.lrprojects.monaserver.model.PinLikeDto
import de.lrprojects.monaserver.service.api.LikeService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import java.util.*

@Component
class LikeController(
    private val likeService: LikeService
): LikesApiDelegate {


    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId) && @guard.isSameUser(authentication, #createLikeDto.userId)")
    override fun createOrUpdateLike(pinId: UUID, createLikeDto: CreateLikeDto): ResponseEntity<PinLikeDto> {
        likeService.createOrUpdateLike(createLikeDto, pinId)
        return ResponseEntity(likeService.likeCountByPin(pinId, createLikeDto.userId), HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinLikes(pinId: UUID): ResponseEntity<PinLikeDto> {
        return ResponseEntity.ok(likeService.likeCountByPin(pinId, UUID.fromString(SecurityContextHolder.getContext().authentication.name)))
    }
}