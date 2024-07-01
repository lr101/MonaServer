package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.UserRepository
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.core.userdetails.UsernameNotFoundException
import org.springframework.stereotype.Component
import java.util.*

@Component
class MyUserDetailsService(@Autowired var userRepository: UserRepository) : UserDetailsService {

    @Throws(UsernameNotFoundException::class)
    override fun loadUserByUsername(username: String): UserDetails {
        val userRes: Optional<User> = userRepository.findByUsername(username)
        if (userRes.isEmpty) throw UsernameNotFoundException("Could not findUser with username = $username")
        val user: User = userRes.get()
        return org.springframework.security.core.userdetails.User(
            username,
            user.id.toString(), listOf(SimpleGrantedAuthority("USER"))
        )
    }
}