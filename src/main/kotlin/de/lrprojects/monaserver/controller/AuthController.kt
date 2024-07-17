package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.AuthApiDelegate
import de.lrprojects.monaserver.excepetion.*
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserLoginRequest
import de.lrprojects.monaserver.model.UserRequestDto
import de.lrprojects.monaserver.service.api.AuthService
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component
import java.util.*

@Component
class AuthController(
    private val authService: AuthService
) : AuthApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun createUser(createUser: UserRequestDto): ResponseEntity<TokenResponseDto>? {
        log.info("Attempting to create user with username: ${createUser.name}")
        val token = authService.signup(createUser.name, createUser.password, createUser.email)
        log.info("Created user with username: ${createUser.name}")
        return ResponseEntity(token, HttpStatus.CREATED)
    }

    override fun generateDeleteCode(username: String): ResponseEntity<Void>? {
        log.info("Generating delete code for user: $username")
        authService.requestDeleteCode(username)
        log.info("Created delete code for user: $username")
        return ResponseEntity.ok().build()
    }

    override fun requestPasswordRecovery(username: String): ResponseEntity<Void> {
        log.info("Attempting password recovery for user: $username")
        return try {
            authService.recoverPassword(username)
            log.info("Created recovery link for user: $username")
            ResponseEntity.ok().build()
        } catch (e: UniqueResetUrlNotFoundException) {
            log.error("Recovery link could not be generated for user: $username")
            ResponseEntity(HttpStatus.SERVICE_UNAVAILABLE)
        }
    }

    override fun userLogin(userLoginRequest: UserLoginRequest): ResponseEntity<TokenResponseDto?> {
        log.info("Attempting login for user: ${userLoginRequest.username}")
        return try {
            val token = authService.login(userLoginRequest.username, userLoginRequest.password)
            log.info("User '${userLoginRequest.username}' has successfully logged in")
            ResponseEntity.ok().body(token)
        } catch (e: WrongPasswordException) {
            log.warn("User '${userLoginRequest.username}' login failed: ${e.message}")
            ResponseEntity.badRequest().build()
        }
    }

    override fun refreshToken(body: UUID): ResponseEntity<TokenResponseDto> {
        log.info("Attempting token refresh")
        return try {
            val token = authService.refreshToken(body)
            log.info("New access token has been generated")
            ResponseEntity.ok().body(token)
        } catch (e: RuntimeException) {
            log.warn("Refresh token failed: ${e.message}")
            ResponseEntity.badRequest().build()
        }
    }

}
