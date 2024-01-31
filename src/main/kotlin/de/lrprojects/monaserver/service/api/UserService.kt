package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.UpdateUserProfileImage200Response
import de.lrprojects.monaserver.model.User


interface UserService {
    fun deleteUser(username: String, code: Int)
    fun getUserProfileImage(username: String): ByteArray?
    fun getUserProfileImageSmall(username: String): ByteArray?
    fun updateUser(username: String, user: User): String
    fun updateUserProfileImage(username: String, image: ByteArray): UpdateUserProfileImage200Response
}