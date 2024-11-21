package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.RefreshToken
import de.lrprojects.monaserver.entity.User
import java.util.*

interface RefreshTokenService {

    fun createRefreshToken(user: User): RefreshToken

    fun findByToken(token: UUID, userId: UUID): Optional<RefreshToken>

    fun verifyExpiration(token: RefreshToken): RefreshToken

    fun invalidateTokens(user: User)

}