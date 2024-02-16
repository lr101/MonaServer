package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.model.UpdateUserProfileImage200Response

fun User.toImages() = UpdateUserProfileImage200Response(this.profilePicture, this.profilePictureSmall)