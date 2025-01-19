package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.types.XpType
import de.lrprojects.monaserver_api.model.TokenResponseDto
import de.lrprojects.monaserver_api.model.UserUpdateDto
import java.util.*


interface UserService {
    fun deleteUser(userId: UUID, code: Int)
    fun getUserProfileImage(userId: UUID): String?
    fun getUserProfileImageSmall(userId: UUID): String?
    fun updateUser(userId: UUID, user: UserUpdateDto): TokenResponseDto?
    fun updateUserProfileImage(userId: UUID, image: ByteArray): User
    fun getUser(userId: UUID): User
    fun getUserByRecoverUrl(recoverUrl: String) : User
    fun getUserByDeletionUrl(deletionUrl: String) : User
    fun getUserByEmailConfirmationUrl(deletionUrl: String): User
    fun addXp(userId: UUID, xpType: XpType)
}