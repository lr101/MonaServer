package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.TokenResponseDto
import de.lrprojects.monaserver.model.UserUpdateDto
import java.util.*


interface UserService {
    fun deleteUser(userId: UUID, code: Int)
    fun getUserProfileImage(userId: UUID): ByteArray?
    fun getUserProfileImageSmall(userId: UUID): ByteArray?
    fun updateUser(userId: UUID, user: UserUpdateDto): TokenResponseDto?
    fun updateUserProfileImage(userId: UUID, image: ByteArray): User
    fun getUser(userId: UUID): User
    fun getUserByRecoverUrl(recoverUrl: String) : User
}