package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfileSmall
import de.lrprojects.monaserver_api.model.UserInfoDto


fun User.toUserUpdateDto(objectService: ObjectService) = UserInfoDto(this.username, this.id!!).also {
    it.profileImageSmall = objectService.getObject(getUserFileProfileSmall(this))
}