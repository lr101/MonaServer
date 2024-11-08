package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Like
import de.lrprojects.monaserver_api.model.CreateLikeDto
import java.util.*


fun CreateLikeDto.toEntity(pinId: UUID) = Like(
    like = if(this.like != null) this.like!! else false,
    likePhotography =  if(this.likePhotography != null) this.likePhotography!! else false,
    likeLocation = if(this.likeLocation != null) this.likeLocation!! else false,
    likeArt = if(this.likeArt != null) this.likeArt!! else false,
    pinId = pinId,
    userId =  this.userId
)