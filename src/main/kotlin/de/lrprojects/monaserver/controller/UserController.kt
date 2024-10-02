package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.UsersApiDelegate
import de.lrprojects.monaserver.converter.toUserUpdateDto
import de.lrprojects.monaserver.model.UserInfoDto
import de.lrprojects.monaserver.model.UserUpdateDto
import de.lrprojects.monaserver.model.UserUpdateResponseDto
import de.lrprojects.monaserver.service.api.UserService
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class UserController(private val userService: UserService) : UsersApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun deleteUser(userId: UUID, body: Int?): ResponseEntity<Unit> {
        log.info("Attempting to delete user with ID: $userId using code: $body")
        userService.deleteUser(userId, body!!)
        log.info("User deleted with ID: $userId")
        return ResponseEntity.ok().build()
    }

    override fun getUserProfileImage(userId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get profile image for user with ID: $userId")
        val image = userService.getUserProfileImage(userId)
        log.info("Retrieved profile image for user with ID: $userId")
        return ResponseEntity.ok(image)
    }

    override fun getUserProfileImageSmall(userId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get small profile image for user with ID: $userId")
        val image = userService.getUserProfileImageSmall(userId)
        log.info("Retrieved small profile image for user with ID: $userId")
        return ResponseEntity.ok(image)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun updateUser(userId: UUID, user: UserUpdateDto): ResponseEntity<UserUpdateResponseDto> {
        log.info("Attempting to update user with ID: $userId")
        var profilePictureSmall: ByteArray? = null
        var profilePicture: ByteArray? = null
        if (user.image != null) {
            log.info("Attempting to update profile image for user with ID: $userId")
            val userEntity = userService.updateUserProfileImage(userId, user.image)
            profilePicture = userEntity.profilePicture
            profilePictureSmall = userEntity.profilePictureSmall
        }
        val token = userService.updateUser(userId, user)
        log.info("User updated with ID: $userId")
        return ResponseEntity.ok(
            UserUpdateResponseDto(
                token,
                profilePictureSmall,
                profilePicture
            )
        )
    }

    override fun getUser(userId: UUID): ResponseEntity<UserInfoDto> {
        log.info("Attempting to get user with ID: $userId")
        val user = userService.getUser(userId)
        log.info("Retrieved user with ID: $userId")
        return ResponseEntity.ok(user.toUserUpdateDto())
    }
}
