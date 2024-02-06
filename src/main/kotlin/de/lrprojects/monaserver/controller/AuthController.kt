package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.excepetion.*
import mu.KotlinLogging
import de.lrprojects.monaserver.api.AuthApi
import de.lrprojects.monaserver.api.AuthApiDelegate
import de.lrprojects.monaserver.model.CreateUser
import de.lrprojects.monaserver.model.UserLogin200Response
import de.lrprojects.monaserver.model.UserLoginRequest
import de.lrprojects.monaserver.service.api.AuthService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.sql.SQLException

@Component
class AuthController(
    @Autowired val authService: AuthService
) : AuthApiDelegate {

    private val logger = KotlinLogging.logger {}

    override fun createUser(createUser: CreateUser): ResponseEntity<String> {

        return try {
            val token = authService.signup(createUser.name, createUser.password, createUser.email)
            logger.info { "Created user with username: ${createUser.name}" }
            ResponseEntity(token, HttpStatus.CREATED)
        } catch (e: UserExistsException) {
            logger.info { "User with username '${createUser.name}' could not be created: ${e.message}" }
            ResponseEntity(e.message, HttpStatus.CONFLICT)
        }
    }

    @PreAuthorize("authentication.name.equals(#username)")
    override fun generateDeleteCode(username: String): ResponseEntity<Void>? {

        return try {
            authService.requestDeleteCode(username)
            logger.info { "Created delete code for user: $username" }
            ResponseEntity.ok().build()
        } catch (e: AttributeDoesNotExist) {
            logger.warn { "Delete code for user '${username}' could not be created: ${e.message}" }
            ResponseEntity.badRequest().build()
        } catch (e: MailException) {
            logger.warn { "Mail with a delete code for user '${username}' could not be send: ${e.message}" }
            ResponseEntity.badRequest().build()
        } catch (e: SQLException) {
            logger.error { "Delete code for user '${username}' could not be saved to database: ${e.message}" }
            ResponseEntity.notFound().build()
        }
    }

    override fun requestPasswordRecovery(username: String): ResponseEntity<Void> {
        return try {
            authService.recoverPassword(username)
            logger.info { "Created recovery link for user: $username" }
            ResponseEntity.ok().build()
        } catch (e: AttributeDoesNotExist) {
            logger.warn { "recovery link for user '${username}' could not be created: ${e.message}" }
            ResponseEntity.badRequest().build()
        } catch (e: MailException) {
            logger.warn { "Mail with a recovery link for user '${username}' could not be send: ${e.message}" }
            ResponseEntity.badRequest().build()
        } catch (e: UniqueResetUrlNotFoundException) {
            logger.error { "recovery link could not be generated for user '${username}'" }
            ResponseEntity(HttpStatus.SERVICE_UNAVAILABLE)
        } catch (e: SQLException) {
            logger.error { "recovery link for user '${username}' could not be saved to database: ${e.message}" }
            ResponseEntity.notFound().build()
        }
    }

    override fun userLogin(userLoginRequest: UserLoginRequest): ResponseEntity<UserLogin200Response> {
        return try {
            val token = authService.login(userLoginRequest.username, userLoginRequest.password)
            logger.info { "User '${userLoginRequest.username}' has successfully logged in" }
            val response = UserLogin200Response()
            response.token = token
            ResponseEntity.ok().body(response)
        } catch (e: UserNotFoundException) {
            logger.warn { "User with username '${userLoginRequest.username}' does not exist: ${e.message}" }
            ResponseEntity.notFound().build()
        } catch (e: WrongPasswordException) {
            logger.warn { "User with username '${userLoginRequest.username}' : ${e.message}" }
            ResponseEntity.badRequest().build()
        }
    }
}