package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toImages
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.model.ProfileImageResponseDto
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserRequestDto
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.RefreshTokenService
import de.lrprojects.monaserver.service.api.UserService
import jakarta.persistence.EntityNotFoundException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class UserServiceImpl(
    val userRepository: UserRepository,
    val refreshTokenService: RefreshTokenService,
    val imageHelper: ImageHelper,
    val tokenHelper: TokenHelper
): UserService {
    override fun deleteUser(userId: UUID, code: Int) {
        val user = userRepository.findByIdAndCode(userId, code.toString())
            .orElseThrow { EntityNotFoundException("user and code in this combination do not exist") }
        userRepository.delete(user)
    }

    override fun getUserProfileImage(userId: UUID): ByteArray? {
        return getUser(userId).profilePicture
    }

    override fun getUserProfileImageSmall(userId: UUID): ByteArray? {
        return getUser(userId).profilePictureSmall
    }

    override fun updateUser(userId: UUID, user: UserRequestDto): TokenResponseDto? {
        val userEntity =  getUser(userId)
        var responseDto: TokenResponseDto? = null
        if (user.email != null) {
            userEntity.email = user.email
        }
        if (user.password != null) {
            userEntity.password = user.password
            refreshTokenService.invalidateTokens(userEntity)
            val accessToken = tokenHelper.generateToken(userEntity.username)
            val refreshToken = refreshTokenService.createRefreshToken(userEntity)
            responseDto = TokenResponseDto(refreshToken.token, accessToken)
        }
        userRepository.save(userEntity)
        return responseDto
    }

    @Throws(UserNotFoundException::class, IllegalStateException::class)
    override fun updateUserProfileImage(
        userId: UUID,
        image: ByteArray
    ): ProfileImageResponseDto {
        val userEntity =  getUser(userId)
        userEntity.profilePicture = imageHelper.getProfileImage(image)
        userEntity.profilePictureSmall = imageHelper.getProfileImageSmall(image)
        return userRepository.save(userEntity).toImages()
    }

    override fun getUser(userId: UUID): de.lrprojects.monaserver.entity.User {
        return getUser(userId)
    }

    override fun getUserByRecoverUrl(recoverUrl: String): de.lrprojects.monaserver.entity.User {
        val list = userRepository.findByResetPasswordUrl(recoverUrl).firstOrNull();
        if (list == null) {
            throw UserNotFoundException("user with this reset url does not exist")
        } else {
            return list
        }
    }
}