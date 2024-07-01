package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.config.TokenProperties
import de.lrprojects.monaserver.entity.RefreshToken
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.RefreshTokenRepository
import de.lrprojects.monaserver.service.api.RefreshTokenService
import jakarta.transaction.Transactional
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.*


@Service
@Transactional
class RefreshTokenServiceImpl(
    private val refreshTokenRepository: RefreshTokenRepository,
    private val tokenProperties: TokenProperties
): RefreshTokenService {

    override fun createRefreshToken(user: User): RefreshToken {
        val refreshToken = RefreshToken(
            token = UUID.randomUUID(),
            user = user,
            expiryDate = Date(Instant.now().plusSeconds(tokenProperties.refreshTokenExploration).toEpochMilli())
        )
        return refreshTokenRepository.save(refreshToken)
    }


    override fun findByToken(token: UUID): Optional<RefreshToken> {
        return refreshTokenRepository.findByToken(token)
    }

    override fun verifyExpiration(token: RefreshToken): RefreshToken {
        if (token.expiryDate < Date(Instant.now().toEpochMilli())) {
            refreshTokenRepository.delete(token)
            throw RuntimeException("Refresh token is expired. Please make a new login..!")
        }
        return token
    }

    override fun invalidateTokens(user: User) {
        refreshTokenRepository.deleteAll(user.refreshTokens)
    }
}