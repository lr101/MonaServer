package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.CreateLikeDto
import de.lrprojects.monaserver.model.PinLikeDto
import java.util.*

interface LikeService {

    fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto
    fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID)
}