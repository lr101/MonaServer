package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.User
import jakarta.validation.constraints.Min
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.*


@Repository
interface UserRepository : JpaRepository<User, String> {
    fun findByResetPasswordUrl(resetPasswordUrl: String): Optional<User>
    fun deleteByUsernameAndCode(username: String, code: String)

    @Query("SELECT lo_get(profile_picture) FROM users WHERE username = ?1", nativeQuery = true)
    fun getProfileImage(username: String): Optional<ByteArray>


    @Query("UPDATE users SET profile_picture = lo_from_bytea(0, ?2) WHERE username = ?1", nativeQuery = true)
    fun setProfileImage(username: String, image: ByteArray)

}