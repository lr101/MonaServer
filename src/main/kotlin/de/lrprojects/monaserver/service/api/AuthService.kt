package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserInfoDto
import java.util.*

interface AuthService {

    @Throws(UserExistsException::class)
    fun signup(username: String, password: String, email: String) : UserInfoDto

    fun login(username: String, password: String) : UserInfoDto

    fun recoverPassword(username: String)

    fun requestDeleteCode(username: String)

    fun refreshToken(token: UUID): TokenResponseDto

}