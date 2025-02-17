package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.properties.AppProperties
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.RefreshTokenService
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import java.util.*

@ExtendWith(MockitoExtension::class)
class AuthServiceImplTest {

    private val userRepository: UserRepository = mock(UserRepository::class.java)
    private val tokenHelper: TokenHelper = mock(TokenHelper::class.java)
    private val emailService: EmailService = mock(EmailService::class.java)
    private val refreshTokenService: RefreshTokenService = mock(RefreshTokenService::class.java)
    private val passwordEncoder: PasswordEncoder = BCryptPasswordEncoder()
    private val appProperties: AppProperties = mock(AppProperties::class.java)


    private val authService = AuthServiceImpl(
        userRepository,
        tokenHelper,
        emailService,
        refreshTokenService,
        passwordEncoder,
        appProperties
    )

    @Test
    fun `should throw UserExistsException when username already exists`() {
        `when`(userRepository.existsByUsername("testUser")).thenReturn(true)

        assertThrows<UserExistsException> {
            authService.signup("testUser", "password123", "test@example.com")
        }
    }


    @Test
    fun `should throw UserNotFoundException on login when user does not exist`() {
        `when`(userRepository.findByUsername("testUser")).thenReturn(Optional.empty())

        assertThrows<UserNotFoundException> {
            authService.login("testUser", "password123")
        }
    }

 @Test
 fun `signup new user success`() {
     val newUser = User(username = "testUser", password = "encodedPass").also {
         it.id = UUID.randomUUID()
         it.emailConfirmationUrl = "confirmationUrl"
         it.email = "test@example.com"
     }
     `when`(userRepository.existsByUsername(newUser.username)).thenReturn(false)
     `when`(userRepository.save(any<User>())).thenReturn(newUser)
     `when`(emailService.sendEmailConfirmation(any<String>(), any<String>(), any<String>())).thenAnswer { }
     `when`(tokenHelper.generateToken(any<UUID>())).thenReturn("token")
     `when`(refreshTokenService.createRefreshToken(any<User>())).thenReturn(mock())

     authService.signup("testUser", "password123", "test@example.com")
 }

}