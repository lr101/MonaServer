package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.converter.toUserUpdateDto
import de.lrprojects.monaserver.converter.toXpDto
import de.lrprojects.monaserver.service.api.AchievementService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver_api.api.UsersApiDelegate
import de.lrprojects.monaserver_api.model.UserAchievementsDtoInner
import de.lrprojects.monaserver_api.model.UserInfoDto
import de.lrprojects.monaserver_api.model.UserUpdateDto
import de.lrprojects.monaserver_api.model.UserUpdateResponseDto
import de.lrprojects.monaserver_api.model.UserXpDto
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class UserController(
    private val userService: UserService,
    private val achievementService: AchievementService
) : UsersApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun deleteUser(userId: UUID, body: Int?): ResponseEntity<Void>? {
        log.info("Attempting to delete user with ID: $userId using code: $body")
        userService.deleteUser(userId, body!!)
        log.info("User deleted with ID: $userId")
        return ResponseEntity.ok().build()
    }

    override fun getUserProfileImage(userId: UUID): ResponseEntity<String> {
        log.info("Attempting to get profile image for user with ID: $userId")
        val image = userService.getUserProfileImage(userId)
        log.info("Retrieved profile image for user with ID: $userId")
        return ResponseEntity.ok(image)
    }

    override fun getUserProfileImageSmall(userId: UUID): ResponseEntity<String> {
        log.info("Attempting to get small profile image for user with ID: $userId")
        val image = userService.getUserProfileImageSmall(userId)
        log.info("Retrieved small profile image for user with ID: $userId")
        return ResponseEntity.ok(image)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun updateUser(userId: UUID, user: UserUpdateDto): ResponseEntity<UserUpdateResponseDto> {
        log.info("Attempting to update user with ID: $userId")
        var profilePictureSmall: String? = null
        var profilePicture: String? = null
        if (user.image != null) {
            log.info("Attempting to update profile image for user with ID: $userId")
            userService.updateUserProfileImage(userId, user.image)
            profilePicture = userService.getUserProfileImage(userId)
            profilePictureSmall = userService.getUserProfileImageSmall(userId)
        }
        val userUpdateDto = userService.updateUser(userId, user)

        log.info("User updated with ID: $userId")
        return ResponseEntity.ok(
            userUpdateDto.also {
                it.profileImageSmall = profilePictureSmall
                it.profileImage = profilePicture
            }
        )
    }

    override fun getUser(userId: UUID): ResponseEntity<UserInfoDto> {
        log.info("Attempting to get user with ID: $userId")
        val user = userService.getUser(userId)
        log.info("Retrieved user with ID: $userId")
        return ResponseEntity.ok(user.toUserUpdateDto())
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun getUserXp(userId: UUID): ResponseEntity<UserXpDto> {
        log.info("Attempting to get user xp with id: $userId")
        val user = userService.getUser(userId)
        log.info("Retrieved user xp with ID: $userId")
        return ResponseEntity.ok(user.toXpDto())
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun getUserAchievements(userId: UUID): ResponseEntity<MutableList<UserAchievementsDtoInner>> {
        log.info("Attempting to get user achievement with user id: $userId")
        return ResponseEntity.ok(achievementService.getAchievement(userId))
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun claimUserAchievement(userId: UUID, achievementId: Int): ResponseEntity<Void> {
        log.info("Attempting to claim achievement $achievementId of user $userId")
        achievementService.claimAchievement(userId, achievementId)
        return ResponseEntity.ok().build()
    }
}
