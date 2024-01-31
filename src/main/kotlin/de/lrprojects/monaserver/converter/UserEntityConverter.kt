package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.UserRepository
import org.openapitools.model.UpdateUserProfileImage200Response

fun User.toImages(userRepository: UserRepository) = UpdateUserProfileImage200Response(userRepository.getProfileImage(this.username!!).get(), this.profilePictureSmall)