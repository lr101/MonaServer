package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.User
import org.springframework.context.annotation.ComponentScan
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.util.Optional
import javax.validation.constraints.Min


@Repository
@Transactional
interface UserRepository : JpaRepository<User, String> {
    fun findByResetPasswordUrl(resetPasswordUrl: String): Optional<User>

    fun deleteByUsernameAndCode(username: @Min(value = 1.toLong()) String, code: Int)


}