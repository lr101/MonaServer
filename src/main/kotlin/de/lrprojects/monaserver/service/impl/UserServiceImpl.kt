package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
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
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
class UserServiceImpl(
    val userRepository: UserRepository,
    val refreshTokenService: RefreshTokenService,
    val imageHelper: ImageHelper,
    val tokenHelper: TokenHelper,
    private val objectService: ObjectService
): UserService {

    @Transactional
    override fun deleteUser(userId: UUID, code: Int) {
        val user = userRepository.findByIdAndCode(userId, code.toString())
            .orElseThrow { EntityNotFoundException("user and code in this combination do not exist") }
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

    override fun updateUser(userId: UUID, user: UserUpdateDto): TokenResponseDto? {
        val userEntity =  getUser(userId)
        var responseDto: TokenResponseDto? = null
        if (user.email != null) {
            userEntity.email = user.email
            userEntity.code = null
        }
        if (user.password != null) {
            userEntity.password = user.password
            userEntity.resetPasswordUrl = null
            refreshTokenService.invalidateTokens(userEntity)
            val accessToken = tokenHelper.generateToken(userEntity.username)
            val refreshToken = refreshTokenService.createRefreshToken(userEntity)
            responseDto = TokenResponseDto(refreshToken.token, accessToken, userEntity.id!!)
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

    override fun getUser(userId: UUID): User {
        return userRepository.findById(userId).orElseThrow { UserNotFoundException("user $userId does not exist") }
    }

    override fun getUserByRecoverUrl(recoverUrl: String): User {
        val list = userRepository.findByResetPasswordUrl(recoverUrl).firstOrNull();
        if (list == null) {
            throw UserNotFoundException("user with this reset url does not exist")
        } else {
            return list
        }
    }
}