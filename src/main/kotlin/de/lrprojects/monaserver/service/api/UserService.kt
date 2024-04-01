package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.UpdateUserProfileImage200Response
import de.lrprojects.monaserver.model.User
import java.util.*


interface UserService {
    fun deleteUser(userId: UUID, code: Int)
    fun getUserProfileImage(userId: UUID): ByteArray?
    fun getUserProfileImageSmall(userId: UUID): ByteArray?
    fun updateUser(userId: UUID, user: User): String
    fun updateUserProfileImage(userId: UUID, image: ByteArray): UpdateUserProfileImage200Response
    fun getUser(userId: UUID): de.lrprojects.monaserver.entity.User
    fun getUserByRecoverUrl(recoverUrl: String) : de.lrprojects.monaserver.entity.User
}