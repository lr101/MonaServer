package de.lrprojects.monaserver.controller

import org.openapitools.api.UsersApi
import org.openapitools.model.UpdateUserProfileImage200Response
import org.openapitools.model.User
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller


@Controller
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
        body: ByteArray?,
    ): ResponseEntity<UpdateUserProfileImage200Response> {
        return super.updateUserProfileImage(username, body)
    }



}