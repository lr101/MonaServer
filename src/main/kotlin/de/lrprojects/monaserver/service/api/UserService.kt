package de.lrprojects.monaserver.service.api

import org.openapitools.model.UpdateUserProfileImageRequest
import org.openapitools.model.User


interface UserService {
    fun deleteUser(username: String?, code: Int?): Void
    fun getUserProfileImage(username: String?): ByteArray
    fun getUserProfileImageSmall(username: String?): ByteArray
    fun updateUser(username: String?, user: User?): String
    fun updateUserProfileImage(username: String?, updateUserProfileImageRequest: UpdateUserProfileImageRequest?): ByteArray
}