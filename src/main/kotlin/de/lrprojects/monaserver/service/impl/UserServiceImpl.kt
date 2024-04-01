package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toImages
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.TokenHelper
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver.model.UpdateUserProfileImage200Response
import de.lrprojects.monaserver.model.User
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*
import kotlin.jvm.Throws
import kotlin.jvm.optionals.getOrElse
import kotlin.jvm.optionals.getOrNull

@Service
@Transactional
class UserServiceImpl constructor(
    @Autowired val userRepository: UserRepository,
    @Autowired val tokenHelper: TokenHelper,
    @Autowired val imageHelper: ImageHelper
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

    override fun updateUser(userId: UUID, user: User): String {
        val userEntity =  getUser(userId)
        if (user.email != null) {
            userEntity.email = user.email
        }
        if (user.password != null) {
            userEntity.password = user.password
            userEntity.token = tokenHelper.generateToken(userEntity.username, user.password, userId)
        }
        return userRepository.save(userEntity).token!!
    }

    @Throws(UserNotFoundException::class, IllegalStateException::class)
    override fun updateUserProfileImage(
        userId: UUID,
        image: ByteArray
    ): UpdateUserProfileImage200Response {
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