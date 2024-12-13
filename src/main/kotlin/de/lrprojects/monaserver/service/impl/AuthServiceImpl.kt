package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.*
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.properties.AppProperties
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.AuthService
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.RefreshTokenService
import de.lrprojects.monaserver_api.model.RefreshTokenRequestDto
import de.lrprojects.monaserver_api.model.TokenResponseDto
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.security.crypto.password.DelegatingPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service
class AuthServiceImpl(
    private val userRepository: UserRepository,
    private val tokenHelper: TokenHelper,
    private val emailService: EmailService,
    private val refreshTokenService: RefreshTokenService,
    private val passwordEncoder: PasswordEncoder,
    private val appProperties: AppProperties
) : AuthService{

    @Throws(UserExistsException::class)
    @Transactional
    override fun signup(username: String, password: String, email: String): TokenResponseDto {
        if (userRepository.existsByUsername(username)) {
            throw UserExistsException("user with username $username already exists")
        }
        var user = User(
            username = username,
            password = passwordEncoder.encode(password),
            email = email
        )
        user = userRepository.save(user)
        val accessToken = tokenHelper.generateToken(user.id!!)
        val refreshToken = refreshTokenService.createRefreshToken(user)

        return TokenResponseDto(refreshToken.token, accessToken, user.id!!)
    }

    @Throws(WrongPasswordException::class, UserNotFoundException::class)
    @Transactional
    override fun login(username: String, password: String): TokenResponseDto {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }
        if (user.failedLoginAttempts >= appProperties.maxLoginAttempts) {
            throw WrongPasswordException("too many wrong login attempts")
        }
        if (!passwordEncoder.matches(password, user.password)) {
            user.failedLoginAttempts += 1
            userRepository.save(user)
            throw WrongPasswordException("password is wrong")
        }
        if (passwordEncoder is DelegatingPasswordEncoder && passwordEncoder.upgradeEncoding(user.password)) {
            user.password = passwordEncoder.encode(password)
            log.info("Password for ${user.username} has been upgraded")
        }
        user.failedLoginAttempts = 0
        userRepository.save(user)
        val accessToken = tokenHelper.generateToken(user.id!!)
        val refreshToken = refreshTokenService.createRefreshToken(user)
        return TokenResponseDto(refreshToken.token, accessToken, user.id!!)
    }

    @Throws(AttributeDoesNotExist::class, MailException::class, UniqueResetUrlNotFoundException::class)
    @Transactional
    override fun recoverPassword(username: String) {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }

        user.resetPasswordUrl = SecurityHelper.generateAlphabeticRandomString(25)
        user.resetPasswordExpiration = OffsetDateTime.now().plusMinutes(10)
        userRepository.save(user)
        emailService.sendRecoveryMail(user.resetPasswordUrl!!, user.email!!)
    }

    @Throws(AttributeDoesNotExist::class, MailException::class)
    @Transactional
    override fun requestDeleteCode(username: String) {
        val user = userRepository.findByUsername(username).orElseThrow { UserNotFoundException("user does not exist") }

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }
        user.code = SecurityHelper.generateSixDigitNumber().toString()
        user.deletionUrl = SecurityHelper.generateAlphabeticRandomString(25)
        user.codeExpiration = OffsetDateTime.now().plusMinutes(10)
        userRepository.save(user)
        emailService.sendDeleteCodeMail(user.username, user.code!!, user.email!!, user.deletionUrl!!)
    }

    @Transactional
    override fun refreshToken(token: RefreshTokenRequestDto): TokenResponseDto {
        val refreshToken = refreshTokenService.findByToken(token.refreshToken, token.userId)
            .orElseThrow { EntityNotFoundException("refresh token not found") }
        refreshTokenService.verifyExpiration(refreshToken)
        return TokenResponseDto(refreshToken.token, tokenHelper.generateToken(refreshToken.user.id!!), refreshToken.user.id!!)
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}