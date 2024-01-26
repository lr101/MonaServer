package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.Optional



@Repository
interface UserRepository : JpaRepository<User, String> {
    fun findByResetPasswordUrl(resetPasswordUrl: String): Optional<User>


}