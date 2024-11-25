package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Like
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver_api.model.CreateLikeDto


fun CreateLikeDto.toEntity(pin: Pin, user: User) = Like(
    like = if(this.like != null) this.like!! else false,
    likePhotography =  if(this.likePhotography != null) this.likePhotography!! else false,
    likeLocation = if(this.likeLocation != null) this.likeLocation!! else false,
    likeArt = if(this.likeArt != null) this.likeArt!! else false,
    pin = pin,
    user =  user
)