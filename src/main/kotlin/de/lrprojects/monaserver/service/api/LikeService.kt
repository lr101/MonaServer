package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver_api.model.CreateLikeDto
import de.lrprojects.monaserver_api.model.PinLikeDto
import de.lrprojects.monaserver_api.model.UserLikesDto
import java.util.*

interface LikeService {

    fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto
    fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID)
    fun getUserLikes(userId: UUID): UserLikesDto
}