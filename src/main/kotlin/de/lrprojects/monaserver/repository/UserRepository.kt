package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface UserRepository : JpaRepository<User, UUID> {
    fun findByResetPasswordUrl(resetPasswordUrl: String): List<User>
    fun findByDeletionUrl(resetPasswordUrl: String): List<User>
    fun findByEmailConfirmationUrl(emailConfirmationUrl: String): List<User>
    fun findByIdAndCode(id: UUID, code: String): Optional<User>
    fun findByUsername(username: String): Optional<User>
    fun existsByUsername(username: String): Boolean

    @Query("SELECT u.email, u.username FROM users u WHERE u.email IS NOT NULL", nativeQuery = true)
    fun findAllEmails(): List<Array<String>>

}