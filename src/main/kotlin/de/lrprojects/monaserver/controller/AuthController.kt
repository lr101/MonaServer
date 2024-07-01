package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.AuthApiDelegate
import de.lrprojects.monaserver.excepetion.*
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserLoginRequest
import de.lrprojects.monaserver.model.UserRequestDto
import de.lrprojects.monaserver.service.api.AuthService
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.sql.SQLException
import java.util.*

@Component
class AuthController(
    private val authService: AuthService
) : AuthApiDelegate {
    

    override fun createUser(createUser: UserRequestDto): ResponseEntity<TokenResponseDto>? {

        return try {
            val token = authService.signup(createUser.name, createUser.password, createUser.email)
            logger.info( "Created user with username: ${createUser.name}")
            ResponseEntity(token, HttpStatus.CREATED)
        } catch (e: UserExistsException) {
            logger.info( "User with username '${createUser.name}' could not be created: ${e.message}")
            ResponseEntity(HttpStatus.CONFLICT)
        } catch (e: NullPointerException) {
            ResponseEntity(HttpStatus.BAD_REQUEST)
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    @PreAuthorize("authentication.name.equals(#username)")
    override fun generateDeleteCode(username: String): ResponseEntity<Void>? {

        return try {
            authService.requestDeleteCode(username)
            logger.info( "Created delete code for user: $username")
            ResponseEntity.ok().build()
        } catch (e: AttributeDoesNotExist) {
            logger.warn( "Delete code for user '${username}' could not be created: ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: MailException) {
            logger.warn( "Mail with a delete code for user '${username}' could not be send: ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: SQLException) {
            logger.error( "Delete code for user '${username}' could not be saved to database: ${e.message}")
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun requestPasswordRecovery(username: String): ResponseEntity<Void> {
        return try {
            authService.recoverPassword(username)
            logger.info( "Created recovery link for user: $username")
            ResponseEntity.ok().build()
        } catch (e: AttributeDoesNotExist) {
            logger.warn( "recovery link for user '${username}' could not be created: ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: MailException) {
            logger.warn( "Mail with a recovery link for user '${username}' could not be send: ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: UniqueResetUrlNotFoundException) {
            logger.error( "recovery link could not be generated for user '${username}'")
            ResponseEntity(HttpStatus.SERVICE_UNAVAILABLE)
        } catch (e: SQLException) {
            logger.error("recovery link for user '${username}' could not be saved to database: ${e.message}")
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun userLogin(userLoginRequest: UserLoginRequest): ResponseEntity<TokenResponseDto?> {
        return try {
            val token = authService.login(userLoginRequest.username, userLoginRequest.password)
            logger.info("User '${userLoginRequest.username}' has successfully logged in")
            ResponseEntity.ok().body(token)
        } catch (e: UserNotFoundException) {
            logger.warn("User with username '${userLoginRequest.username}' does not exist: ${e.message}")
            ResponseEntity.notFound().build()
        } catch (e: WrongPasswordException) {
            logger.warn("User with username '${userLoginRequest.username}' : ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

    override fun refreshToken(body: UUID): ResponseEntity<TokenResponseDto> {
        return try {
            val token = authService.refreshToken(body)
            logger.info("New access token has been generated")
            ResponseEntity.ok().body(token)
        } catch (e: RuntimeException) {
            logger.warn("Refresh token is expired: ${e.message}")
            ResponseEntity.badRequest().build()
        } catch (e: EntityNotFoundException) {
            logger.warn("Refresh token does not exist: ${e.message}")
            ResponseEntity.notFound().build()
        }
    }
    
    companion object {
        private val logger = LoggerFactory.getLogger(this::class.java)
    }
    
}