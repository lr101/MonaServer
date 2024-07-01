package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.RefreshToken
import org.springframework.data.repository.CrudRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface RefreshTokenRepository: CrudRepository<RefreshToken, UUID> {
    fun findByToken(token: UUID): Optional<RefreshToken>
}
