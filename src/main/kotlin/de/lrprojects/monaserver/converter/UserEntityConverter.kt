package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import org.openapitools.model.UpdateUserProfileImage200Response

fun User.toImages() = UpdateUserProfileImage200Response(this.profilePicture, this.profilePictureSmall)