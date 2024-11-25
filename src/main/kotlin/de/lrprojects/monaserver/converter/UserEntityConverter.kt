package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver_api.model.UserInfoDto


fun User.toUserUpdateDto() = UserInfoDto(this.username, this.id!!).also {
    it.description = this.description
}