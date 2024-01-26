package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toImages
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.TokenHelper
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.UserService
import org.openapitools.model.UpdateUserProfileImage200Response
import org.openapitools.model.User
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.jvm.optionals.getOrElse

@Service

class UserServiceImpl constructor(
    @Autowired val userRepository: UserRepository,
    @Autowired val tokenHelper: TokenHelper,
    @Autowired val imageHelper: ImageHelper
    ): UserService {
    override fun deleteUser(username: String, code: Int) {
        userRepository.deleteByUsernameAndCode(username, code)
    }

    override fun getUserProfileImage(username: String): ByteArray? {
        return userRepository.findById(username).getOrElse { throw UserNotFoundException("user not found") }.profilePicture
    }

    override fun getUserProfileImageSmall(username: String): ByteArray? {
        return userRepository.findById(username).getOrElse { throw UserNotFoundException("user not found") }.profilePictureSmall
    }

    override fun updateUser(username: String, user: User): String {
        val userEntity =  userRepository.findById(username).getOrElse { throw UserNotFoundException("user not found") }
        if (user.email != null) {
            userEntity.email = user.email
        }
        if (user.password != null) {
            userEntity.password = user.password
            userEntity.token = tokenHelper.generateToken(username, user.password)
        }
        return userRepository.save(userEntity).token!!
    }

    override fun updateUserProfileImage(
        username: String,
        image: ByteArray
    ): UpdateUserProfileImage200Response {
        val userEntity =  userRepository.findById(username).getOrElse { throw UserNotFoundException("user not found") }
        userEntity.profilePicture = imageHelper.getProfileImage(image)
        userEntity.profilePictureSmall = imageHelper.getProfileImageSmall(image)
        return userRepository.save(userEntity).toImages()
    }
}