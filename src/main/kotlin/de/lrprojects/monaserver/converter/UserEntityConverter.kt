package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.ProfileImageResponseDto
import de.lrprojects.monaserver.model.UserInfoDto

fun User.toImages() = ProfileImageResponseDto(this.profilePicture, this.profilePictureSmall)

fun User.toUserUpdateDto() = UserInfoDto(this.username, this.id)