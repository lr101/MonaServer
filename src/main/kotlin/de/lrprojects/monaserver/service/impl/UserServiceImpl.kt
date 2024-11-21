package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.TimeExpiredException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.api.RefreshTokenService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfile
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getUserFileProfileSmall
import de.lrprojects.monaserver_api.model.TokenResponseDto
import de.lrprojects.monaserver_api.model.UserUpdateDto
import io.minio.errors.MinioException
import jakarta.persistence.EntityNotFoundException
import org.springframework.cache.annotation.CacheEvict
import org.springframework.cache.annotation.Cacheable
import org.springframework.cache.annotation.Caching
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service
class UserServiceImpl(
    val userRepository: UserRepository,
    val refreshTokenService: RefreshTokenService,
    val imageHelper: ImageHelper,
    val tokenHelper: TokenHelper,
    private val objectService: ObjectService,
    private val passwordEncoder: PasswordEncoder
): UserService {

    @Transactional
    @Caching(
        evict = [
            CacheEvict(value = ["pinsByUser"], key = "#userId"),
            CacheEvict(value = ["pinsByGroup"], allEntries = true),
            CacheEvict(value = ["refreshToken"], allEntries = true),
            CacheEvict(value = ["userGroups"], key = "#userId"),
            CacheEvict(value = ["groupMembers"], allEntries = true),
            CacheEvict(value = ["isInGroup"], allEntries = true),
            CacheEvict(value = ["groupsByPin"], allEntries = true),
            CacheEvict(value = ["users"], key = "#userId"),
        ]
    )
    override fun deleteUser(userId: UUID, code: Int) {
        val user = userRepository.findByIdAndCode(userId, code.toString())
            .orElseThrow { EntityNotFoundException("user and code in this combination do not exist") }
        if (OffsetDateTime.now().isAfter(user.codeExpiration!!)) {
            throw TimeExpiredException("code is expired")
        }
        refreshTokenService.invalidateTokens(user)
        userRepository.delete(user)
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

    @CacheEvict(value = ["users"], key = "#userId")
    @Transactional
    override fun updateUser(userId: UUID, user: UserUpdateDto): TokenResponseDto? {
        val userEntity =  getUser(userId)
        var responseDto: TokenResponseDto? = null
        if (user.email != null) {
            userEntity.email = user.email
            userEntity.code = null
            userEntity.codeExpiration = null
        }
        if (user.password != null) {
            userEntity.password = passwordEncoder.encode(user.password)
            userEntity.resetPasswordUrl = null
            userEntity.resetPasswordExpiration = null
            userEntity.failedLoginAttempts = 0
            refreshTokenService.invalidateTokens(userEntity)
            val accessToken = tokenHelper.generateToken(userEntity.id!!)
            val refreshToken = refreshTokenService.createRefreshToken(userEntity)
            responseDto = TokenResponseDto(refreshToken.token, accessToken, userEntity.id!!)
        }
        if (user.description != null) {
            userEntity.description = user.description
        }
        if (user.username != null) {
            if (userEntity.lastUsernameUpdate != null && OffsetDateTime.now().isBefore(userEntity.lastUsernameUpdate!!.plusDays(USERNAME_CHANGE_TIMEOUT))) { throw TimeExpiredException("username can only be changed once every 14 days") }
            userRepository.findByUsername(user.username).ifPresent { throw UserExistsException("user with this username already exists") }
            userEntity.username = user.username
            userEntity.lastUsernameUpdate = OffsetDateTime.now()
        }
        userRepository.save(userEntity)
        return responseDto
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

    @Cacheable(value = ["users"], key = "#userId")
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

    companion object {
        private const val USERNAME_CHANGE_TIMEOUT: Long = 14
    }
}