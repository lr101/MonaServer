package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.*
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.AuthService
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.RefreshTokenService
import jakarta.persistence.EntityNotFoundException
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class AuthServiceImpl(
    private val userRepository: UserRepository,
    private val tokenHelper: TokenHelper,
    private val emailService: EmailService,
    private val refreshTokenService: RefreshTokenService,
    private val passwordEncoder: PasswordEncoder,
) : AuthService{

    @Throws(UserExistsException::class)
    override fun signup(username: String, password: String, email: String): TokenResponseDto {
        if (userRepository.existsByUsername(username)) {
            throw UserExistsException("user with username " + username + "already exists")
        }
        var user = User(
            username = username,
            password = passwordEncoder.encode(password),
            email = email
        )
        user = userRepository.save(user)
        val accessToken = tokenHelper.generateToken(username)
        val refreshToken = refreshTokenService.createRefreshToken(user)

        return TokenResponseDto(refreshToken.token, accessToken, user.id!!)
    }

    @Throws(WrongPasswordException::class, UserNotFoundException::class)
    override fun login(username: String, password: String): TokenResponseDto {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }
        if (passwordEncoder.matches(password, user.password)) {
            throw WrongPasswordException("password is wrong")
        }
        val accessToken = tokenHelper.generateToken(username)
        val refreshToken = refreshTokenService.createRefreshToken(user)
        return TokenResponseDto(refreshToken.token, accessToken, user.id!!)
    }

    @Throws(AttributeDoesNotExist::class, MailException::class, UniqueResetUrlNotFoundException::class)
    override fun recoverPassword(username: String) {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }

        user.resetPasswordUrl = SecurityHelper.generateAlphabeticRandomString(25)
        userRepository.save(user)
        emailService.sendRecoveryMail(user.resetPasswordUrl!!, user.email!!)
    }

    @Throws(AttributeDoesNotExist::class, MailException::class)
    override fun requestDeleteCode(username: String) {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }
        user.code = SecurityHelper.generateSixDigitNumber().toString()
        user.resetPasswordUrl = SecurityHelper.generateAlphabeticRandomString(25)
        userRepository.save(user)
        emailService.sendDeleteCodeMail(user.username, user.code!!, user.email!!, user.resetPasswordUrl!!)
    }

    override fun refreshToken(token: UUID): TokenResponseDto {
        val refreshToken = refreshTokenService.findByToken(token)
            .orElseThrow { EntityNotFoundException("refresh token not found") }
        refreshTokenService.verifyExpiration(refreshToken)
        return TokenResponseDto(refreshToken.token, tokenHelper.generateToken(refreshToken.user.username), refreshToken.user.id!!)
    }
}