package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.LikeService
import de.lrprojects.monaserver_api.api.LikesApiDelegate
import de.lrprojects.monaserver_api.model.CreateLikeDto
import de.lrprojects.monaserver_api.model.PinLikeDto
import de.lrprojects.monaserver_api.model.UserLikesDto
import org.slf4j.LoggerFactory
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

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }


    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId) && @guard.isSameUser(authentication, #createLikeDto.userId)")
    override fun createOrUpdateLike(pinId: UUID, createLikeDto: CreateLikeDto): ResponseEntity<PinLikeDto> {
        log.info("Attempting to update like for pin with ID: $pinId by user with ID: ${createLikeDto.userId}")
        likeService.createOrUpdateLike(createLikeDto, pinId)
        return ResponseEntity(likeService.likeCountByPin(pinId, createLikeDto.userId), HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinLikes(pinId: UUID): ResponseEntity<PinLikeDto> {
        log.info("Attempting to get likes for pin with ID: $pinId")
        return ResponseEntity.ok(likeService.likeCountByPin(pinId, UUID.fromString(SecurityContextHolder.getContext().authentication.name)))
    }

    override fun getUserLikes(userId: UUID): ResponseEntity<UserLikesDto> {
        log.info("Attempting to get likes for user with ID: $userId")
        return ResponseEntity.ok(likeService.getUserLikes(userId))
    }
}