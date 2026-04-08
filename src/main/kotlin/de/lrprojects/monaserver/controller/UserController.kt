package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.converter.toUserInfoDto
import de.lrprojects.monaserver.converter.toXpDto
import de.lrprojects.monaserver.service.api.AchievementService
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserverapi.api.UsersApiDelegate
import de.lrprojects.monaserverapi.model.UserAchievementsDtoInner
import de.lrprojects.monaserverapi.model.UserInfoDto
import de.lrprojects.monaserverapi.model.UserUpdateDto
import de.lrprojects.monaserverapi.model.UserUpdateResponseDto
import de.lrprojects.monaserverapi.model.UserXpDto
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.net.URI
import java.util.*

@Component
class UserController(
    private val userService: UserService,
    private val achievementService: AchievementService,
    private val seasonService: SeasonService
) : UsersApiDelegate {

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

    override fun getUserProfileImage(userId: UUID, redirect: Boolean): ResponseEntity<String> {
        log.info("Attempting to get profile image for user with ID: $userId")
        val image = userService.getUserProfileImage(userId)
        log.info("Retrieved profile image for user with ID: $userId")
        if (redirect && image != null) {
            return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(image))
                .build()
        }
        return ResponseEntity.ok(image)
    }

    override fun getUserProfileImageSmall(userId: UUID, redirect: Boolean): ResponseEntity<String> {
        log.info("Attempting to get small profile image for user with ID: $userId")
        val image = userService.getUserProfileImageSmall(userId)
        log.info("Retrieved small profile image for user with ID: $userId")
        if (redirect && image != null) {
            return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(image))
                .build()
        }
        return ResponseEntity.ok(image)
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun updateUser(userId: UUID, userUpdateDto: UserUpdateDto): ResponseEntity<UserUpdateResponseDto> {
        log.info("Attempting to update user with ID: $userId")
        var profilePictureSmall: String? = null
        var profilePicture: String? = null
        if (userUpdateDto.image != null) {
            log.info("Attempting to update profile image for user with ID: $userId")
            userService.updateUserProfileImage(userId, userUpdateDto.image!!)
            profilePicture = userService.getUserProfileImage(userId)
            profilePictureSmall = userService.getUserProfileImageSmall(userId)
        }
        val userUpdateResponseDto = userService.updateUser(userId, userUpdateDto, profilePicture, profilePictureSmall)

        log.info("User updated with ID: $userId")
        return ResponseEntity.ok(userUpdateResponseDto)
    }

    override fun getUser(userId: UUID): ResponseEntity<UserInfoDto> {
        log.info("Attempting to get user with ID: $userId")
        val user = userService.getUser(userId)
        log.info("Retrieved user with ID: $userId")
        return ResponseEntity.ok(user.toUserInfoDto(seasonService))
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun getUserXp(userId: UUID): ResponseEntity<UserXpDto> {
        log.info("Attempting to get user xp with id: $userId")
        val user = userService.getUser(userId)
        log.info("Retrieved user xp with ID: $userId")
        return ResponseEntity.ok(user.toXpDto())
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun getUserAchievements(userId: UUID): ResponseEntity<List<UserAchievementsDtoInner>> {
        log.info("Attempting to get user achievement with user id: $userId")
        return ResponseEntity.ok(achievementService.getAchievement(userId))
    }

    @PreAuthorize("@guard.isSameUser(authentication, #userId)")
    override fun claimUserAchievement(userId: UUID, achievementId: Int): ResponseEntity<Unit> {
        log.info("Attempting to claim achievement $achievementId of user $userId")
        achievementService.claimAchievement(userId, achievementId)
        return ResponseEntity.ok().build()
    }
}
