package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.RefreshToken
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.properties.TokenProperties
import de.lrprojects.monaserver.repository.RefreshTokenRepository
import de.lrprojects.monaserver.service.api.RefreshTokenService
import jakarta.persistence.EntityNotFoundException
import jakarta.transaction.Transactional
import org.springframework.stereotype.Service
import java.time.OffsetDateTime
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
            lastActiveDate = OffsetDateTime.now()
        )
        return refreshTokenRepository.save(refreshToken)
    }

    @Transactional
    override fun findByToken(token: UUID, userId: UUID): RefreshToken {
        val refreshToken = refreshTokenRepository.findByTokenAndUser_Id(token, userId)
            .orElseThrow { EntityNotFoundException("refresh token not found") }
        return verifyExpiration(refreshToken)
    }

    override fun verifyExpiration(token: RefreshToken): RefreshToken {
        if (token.lastActiveDate.plusSeconds(tokenProperties.refreshTokenExploration).isBefore(OffsetDateTime.now())) {
            refreshTokenRepository.delete(token)
            throw RuntimeException("Refresh token is expired. Please make a new login..!")
        }
        token.lastActiveDate = OffsetDateTime.now()
        val updatedToken = refreshTokenRepository.save(token)
        return updatedToken
    }

    override fun invalidateTokens(user: User) {
        refreshTokenRepository.deleteAll(user.refreshTokens)
    }
}