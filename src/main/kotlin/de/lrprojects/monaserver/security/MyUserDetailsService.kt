package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.config.RoleConstants.USER_ROLE
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.UserRepository
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.core.userdetails.UsernameNotFoundException
import org.springframework.stereotype.Component
import java.util.*

@Component
class MyUserDetailsService(private val userRepository: UserRepository) : UserDetailsService {

    @Throws(UsernameNotFoundException::class)
    override fun loadUserByUsername(username: String): UserDetails {
        val userRes: Optional<User> = userRepository.findByUsername(username)
        if (userRes.isEmpty) throw UsernameNotFoundException("Could not findUser with username = $username")
        val user: User = userRes.get()
        return org.springframework.security.core.userdetails.User(
            user.id.toString(), user.username, listOf(SimpleGrantedAuthority(USER_ROLE))
        )
    }
}