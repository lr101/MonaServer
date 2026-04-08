package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserverapi.model.CreateLikeDto
import de.lrprojects.monaserverapi.model.PinLikeDto
import de.lrprojects.monaserverapi.model.UserLikesDto
import java.util.*

interface LikeService {

    fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto
    fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID)
    fun getUserLikes(userId: UUID): UserLikesDto
}