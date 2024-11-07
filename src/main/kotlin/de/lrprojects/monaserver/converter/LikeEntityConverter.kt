package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Like
import de.lrprojects.monaserver.model.CreateLikeDto
import java.util.*


fun CreateLikeDto.toEntity(pinId: UUID) = Like(
    like = this.like,
    likePhotography =  this.likePhotography,
    likeLocation = this.likeLocation,
    likeArt = this.likeArt,
    pinId = pinId,
    userId =  this.userId
)