package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.User
import org.springframework.data.domain.Pageable
import org.springframework.data.repository.CrudRepository
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface UserRepository : CrudRepository<User, UUID> {
    fun findByResetPasswordUrl(resetPasswordUrl: String): List<User>
    fun findByIdAndCode(id: UUID, code: String): Optional<User>
    fun findByUsername(username: String): Optional<User>
    fun existsByUsername(username: String): Boolean
    fun findUserByProfilePictureNotNull(pageable: Pageable): List<User>
}