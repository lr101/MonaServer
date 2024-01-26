package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.UserService
import org.openapitools.model.UpdateUserProfileImageRequest
import org.openapitools.model.User
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class UserServiceImpl constructor(@Autowired userRepository: UserRepository): UserService {
    override fun deleteUser(username: String?, code: Int?): Void {
        TODO("Not yet implemented")
    }

    override fun getUserProfileImage(username: String?): ByteArray {
        TODO("Not yet implemented")
    }

    override fun getUserProfileImageSmall(username: String?): ByteArray {
        TODO("Not yet implemented")
    }

    override fun updateUser(username: String?, user: User?): String {
        TODO("Not yet implemented")
    }

    override fun updateUserProfileImage(
        username: String?,
        updateUserProfileImageRequest: UpdateUserProfileImageRequest?
    ): ByteArray {
        TODO("Not yet implemented")
    }
}