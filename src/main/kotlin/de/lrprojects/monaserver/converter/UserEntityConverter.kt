package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.ProfileImageResponseDto

fun User.toImages() = ProfileImageResponseDto(this.profilePicture, this.profilePictureSmall)