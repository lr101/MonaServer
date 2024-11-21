package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.RefreshToken
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface RefreshTokenRepository: JpaRepository<RefreshToken, UUID> {
    fun findByTokenAndUser_Id(token: UUID, id: UUID): Optional<RefreshToken>
}
