package de.lrprojects.monaserver.controller

import org.openapitools.api.UsersApi
import org.openapitools.model.UpdateUserProfileImageRequest
import org.openapitools.model.User
import org.springframework.http.ResponseEntity


class UserController () : UsersApi {
    override fun deleteUser(username: String?, code: Int?): ResponseEntity<Void> {
        return super.deleteUser(username, code)
    }

    override fun getUserProfileImage(username: String?): ResponseEntity<ByteArray> {
        return super.getUserProfileImage(username)
    }

    override fun getUserProfileImageSmall(username: String?): ResponseEntity<ByteArray> {
        return super.getUserProfileImageSmall(username)
    }

    override fun updateUser(username: String?, user: User?): ResponseEntity<String> {
        return super.updateUser(username, user)
    }

    override fun updateUserProfileImage(
        username: String?,
        updateUserProfileImageRequest: UpdateUserProfileImageRequest?
    ): ResponseEntity<ByteArray> {
        return super.updateUserProfileImage(username, updateUserProfileImageRequest)
    }


}