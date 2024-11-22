package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import java.util.*

interface ObjectService {

    fun createObject(pin: Pin, image: ByteArray): String

    fun createObject(group: Group, imagePin: ByteArray, imageProfile: ByteArray, imageProfileSmall: ByteArray)

    fun createObject(user: User, profileImage: ByteArray, profileImageSmall: ByteArray)

    fun deletePinObject(pinId: UUID)

    fun deleteGroupObject(groupId: UUID)

    fun deleteUserObject(userId: UUID)

    fun getObject(pin: Pin): String

    fun getObject(file: String): String

}
