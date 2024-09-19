package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.UserInfoDto


fun User.toUserUpdateDto() = UserInfoDto(this.username, this.id).also {
    it.profileImageSmall = this.profilePictureSmall
}