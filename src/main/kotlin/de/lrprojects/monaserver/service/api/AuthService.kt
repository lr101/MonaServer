package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver_api.model.RefreshTokenRequestDto
import de.lrprojects.monaserver_api.model.TokenResponseDto
import java.util.*

interface AuthService {

    @Throws(UserExistsException::class)
    fun signup(username: String, password: String, email: String) : TokenResponseDto

    fun login(username: String, password: String) : TokenResponseDto

    fun recoverPassword(username: String)

    fun requestDeleteCode(username: String)

    fun refreshToken(token: RefreshTokenRequestDto): TokenResponseDto

}