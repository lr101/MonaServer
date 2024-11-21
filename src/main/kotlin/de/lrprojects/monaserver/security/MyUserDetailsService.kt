package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.properties.RoleConstants.ADMIN_ROLE
import de.lrprojects.monaserver.properties.RoleConstants.USER_ROLE
import de.lrprojects.monaserver.properties.TokenProperties
import de.lrprojects.monaserver.repository.UserRepository
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.core.userdetails.UsernameNotFoundException
import java.util.*


class MyUserDetailsService(
    private val userRepository: UserRepository,
    private val tokenProperties: TokenProperties
) : UserDetailsService {

    @Throws(UsernameNotFoundException::class)
    override fun loadUserByUsername(username: String): UserDetails {
        val userRes: Optional<User> = userRepository.findById(UUID.fromString(username))
        if (userRes.isEmpty) throw UsernameNotFoundException("Could not findUser with username = $username")
        val user: User = userRes.get()
        val roles = mutableListOf(SimpleGrantedAuthority(USER_ROLE))
        if (user.username == tokenProperties.adminAccountName) {
            roles.add(SimpleGrantedAuthority(ADMIN_ROLE))
        }
        return org.springframework.security.core.userdetails.User(
            user.id.toString(), user.password, roles
        )
    }
}