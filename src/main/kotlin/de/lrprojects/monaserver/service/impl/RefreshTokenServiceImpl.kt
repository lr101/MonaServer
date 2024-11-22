package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.RefreshToken
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.properties.TokenProperties
import de.lrprojects.monaserver.repository.RefreshTokenRepository
import de.lrprojects.monaserver.service.api.RefreshTokenService
import org.springframework.cache.annotation.CacheEvict
import org.springframework.cache.annotation.Cacheable
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.*


@Service
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


    @Cacheable(value = ["refreshToken"], key = "{#token, #userId}")
    override fun findByToken(token: UUID, userId: UUID): Optional<RefreshToken> {
        return refreshTokenRepository.findByTokenAndUser_Id(token, userId)
    }

    override fun verifyExpiration(token: RefreshToken): RefreshToken {
        if (token.expiryDate < Date(Instant.now().toEpochMilli())) {
            refreshTokenRepository.delete(token)
            throw RuntimeException("Refresh token is expired. Please make a new login..!")
        }
        return token
    }

    @CacheEvict(value = ["refreshToken"], allEntries = true)
    override fun invalidateTokens(user: User) {
        refreshTokenRepository.deleteAll(user.refreshTokens)
    }
}