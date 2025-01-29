package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.setEmailConfirmationUrl
import de.lrprojects.monaserver.converter.toUserUpdateDto
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.EmailNotConfirmedException
import de.lrprojects.monaserver.excepetion.TimeExpiredException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.repository.AchievementRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.service.api.RefreshTokenService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfile
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfileSmall
import de.lrprojects.monaserver.types.XpType
import de.lrprojects.monaserver_api.model.TokenResponseDto
import de.lrprojects.monaserver_api.model.UserUpdateDto
import de.lrprojects.monaserver_api.model.UserUpdateResponseDto
import io.minio.errors.MinioException
import jakarta.persistence.EntityNotFoundException
import org.springframework.cache.annotation.CacheEvict
import org.springframework.cache.annotation.Caching
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service
class UserServiceImpl(
    private val userRepository: UserRepository,
    private val refreshTokenService: RefreshTokenService,
    private val imageHelper: ImageHelper,
    private val tokenHelper: TokenHelper,
    private val objectService: ObjectService,
    private val passwordEncoder: PasswordEncoder,
    private val pinService: PinService,
    private val achievementRepository: AchievementRepository,
    private val emailService: EmailService
): UserService {

    @Transactional
    @Caching(
        evict = [
            CacheEvict(value = ["pinsByUser"], key = "#userId"),
            CacheEvict(value = ["pinsByGroup"], allEntries = true),
            CacheEvict(value = ["refreshToken"], allEntries = true),
            CacheEvict(value = ["userGroups"], key = "#userId"),
            CacheEvict(value = ["isInGroup"], allEntries = true),
            CacheEvict(value = ["groupsByPin"], allEntries = true),
            CacheEvict(value = ["pinImage"], allEntries = true),
        ]
    )
    override fun deleteUser(userId: UUID, code: Int) {
        val user = userRepository.findByIdAndCode(userId, code.toString())
            .orElseThrow { EntityNotFoundException("user and code in this combination do not exist") }
        if (OffsetDateTime.now().isAfter(user.codeExpiration!!)) {
            throw TimeExpiredException("code is expired")
        }
        val ids = pinService.getUserPins(user)
        userRepository.saveAndFlush(user)
        userRepository.deleteById(userId)
        pinService.deleteObjectsByList(ids)
    }

    override fun getUserProfileImage(userId: UUID): String? {
        try {
            val user = getUser(userId)
            if (user.profilePictureExists) {
                return objectService.getObject(getUserFileProfile(user))
            }
        } catch (_: MinioException) {

        }
        return  null
    }

    override fun getUserProfileImageSmall(userId: UUID): String? {
        try {
            val user = getUser(userId)
            if (user.profilePictureExists) {
                return objectService.getObject(getUserFileProfileSmall(user))
            }
        } catch (_: MinioException) { }
        return  null
    }

    @Transactional
    override fun updateUser(userId: UUID, user: UserUpdateDto): UserUpdateResponseDto {
        val userEntity = getUser(userId)
        var tokenResponse: TokenResponseDto? = null

        if (user.email != null) updateUserEmail(user, userEntity)
        if (user.password != null) tokenResponse = updateUserPassword(user, userEntity)
        if (user.description != null) userEntity.description = user.description
        if (user.selectedBatch != null) updateUserBatch(userId, user, userEntity)
        if (user.username != null) updateUserUsername(user, userEntity)

        userRepository.save(userEntity)
        if (user.email != null) sendEmailConfirmation(userEntity)

        return UserUpdateResponseDto().also {
            it.userTokenDto = tokenResponse
            it.userInfoDto = userEntity.toUserUpdateDto()
        }
    }

    private fun updateUserEmail(user: UserUpdateDto, userEntity: User) {
        if (!userEntity.emailConfirmed) throw EmailNotConfirmedException("email is not confirmed")
        userEntity.email = user.email
        userEntity.code = null
        userEntity.codeExpiration = null
        userEntity.setEmailConfirmationUrl()
    }

    private fun updateUserPassword(user: UserUpdateDto, userEntity: User): TokenResponseDto {
        userEntity.password = passwordEncoder.encode(user.password)
        userEntity.resetPasswordUrl = null
        userEntity.resetPasswordExpiration = null
        userEntity.failedLoginAttempts = 0

        refreshTokenService.invalidateTokens(userEntity)

        val accessToken = tokenHelper.generateToken(userEntity.id!!)
        val refreshToken = refreshTokenService.createRefreshToken(userEntity)
        return TokenResponseDto(refreshToken.token, accessToken, userEntity.id!!)
    }

    private fun updateUserBatch(userId: UUID, user: UserUpdateDto, userEntity: User) {
        val batch = achievementRepository.findByUser_IdAndAchievementId(userId, user.selectedBatch)
            .orElseThrow { EntityNotFoundException("Achievement not found") }
        if (batch.claimed) userEntity.selectedBatch = batch
    }

    private fun updateUserUsername(user: UserUpdateDto, userEntity: User) {
        if (userEntity.lastUsernameUpdate != null && OffsetDateTime.now()
                .isBefore(userEntity.lastUsernameUpdate!!.plusDays(USERNAME_CHANGE_TIMEOUT))
        ) {
            throw TimeExpiredException("username can only be changed once every 14 days")
        }
        userRepository.findByUsername(user.username)
            .ifPresent { throw UserExistsException("user with this username already exists") }
        userEntity.username = user.username
        userEntity.lastUsernameUpdate = OffsetDateTime.now()
    }

    private fun sendEmailConfirmation(userEntity: User) {
        emailService.sendEmailConfirmation(userEntity.username, userEntity.email!!, userEntity.emailConfirmationUrl!!)
    }



    @Throws(UserNotFoundException::class, IllegalStateException::class)
    override fun updateUserProfileImage(
        userId: UUID,
        image: ByteArray
    ): User {
        val userEntity =  getUser(userId)
        val processedImage = imageHelper.getProfileImage(image)
        val processedImageSmall = imageHelper.getProfileImageSmall(image)
        objectService.createObject(userEntity, processedImage, processedImageSmall)
        userEntity.profilePictureExists = true
        return userRepository.save(userEntity)
    }

    override fun getUser(userId: UUID): User {
        return userRepository.findById(userId).orElseThrow { UserNotFoundException("user $userId does not exist") }
    }

    override fun getUserByRecoverUrl(recoverUrl: String): User {
        val list = userRepository.findByResetPasswordUrl(recoverUrl).firstOrNull();
        if (list == null) {
            throw UserNotFoundException("user with this reset url does not exist")
        } else {
            if (OffsetDateTime.now().isBefore(list.resetPasswordExpiration!!)) {
                return list
            }
            throw TimeExpiredException("reset url is expired")
        }
    }

    override fun getUserByDeletionUrl(deletionUrl: String): User {
        val list = userRepository.findByDeletionUrl(deletionUrl).firstOrNull();
        if (list == null) {
            throw UserNotFoundException("user with this reset url does not exist")
        } else {
            if (OffsetDateTime.now().isBefore(list.codeExpiration!!)) {
                return list
            }
            throw TimeExpiredException("deletion url is expired")
        }
    }

    override fun getUserByEmailConfirmationUrl(deletionUrl: String): User {
        val user = userRepository.findByEmailConfirmationUrl(deletionUrl).firstOrNull();
        if (user == null) {
            throw UserNotFoundException("user with this reset url does not exist")
        } else {
            user.emailConfirmed = true
            user.emailConfirmationUrl = null
           return userRepository.save(user)
        }
    }

    override fun addXp(userId: UUID, xpType: XpType) {
        val user = getUser(userId)
        user.xp += xpType.xpValue
        userRepository.save(user)
    }

    companion object {
        private const val USERNAME_CHANGE_TIMEOUT: Long = 14
    }
}