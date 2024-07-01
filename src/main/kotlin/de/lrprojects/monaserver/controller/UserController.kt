package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.UsersApiDelegate
import de.lrprojects.monaserver.excepetion.ImageNotSquareException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.ProfileImageResponseDto
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserRequestDto
import de.lrprojects.monaserver.service.api.UserService
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*


@Component
class UserController (private val userService: UserService) : UsersApiDelegate {

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun deleteUser(userId: UUID, code: Int): ResponseEntity<Void> {
        return try {
            userService.deleteUser(userId, code)
            ResponseEntity.ok().build()
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun getUserProfileImage(userId: UUID): ResponseEntity<ByteArray> {
        return try {
            val image = userService.getUserProfileImage(userId)
            ResponseEntity.ok(image)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun getUserProfileImageSmall(userId: UUID): ResponseEntity<ByteArray> {
        return try {
            val image = userService.getUserProfileImageSmall(userId)
            ResponseEntity.ok(image)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun updateUser(userId: UUID, user: UserRequestDto): ResponseEntity<TokenResponseDto?> {
        return try {
            val token = userService.updateUser(userId, user)
            ResponseEntity.ok(token)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun updateUserProfileImage(
        userId: UUID,
        body: ByteArray,
    ): ResponseEntity<ProfileImageResponseDto> {
        return try {
            val images = userService.updateUserProfileImage(userId, body)
            return ResponseEntity.ok(images)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: ImageNotSquareException) {
            ResponseEntity.badRequest().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }



}