package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User

interface ObjectService {

    fun createObject(pin: Pin, image: ByteArray): String

    fun createObject(group: Group, imagePin: ByteArray, imageProfile: ByteArray)

    fun createObject(user: User, profileImage: ByteArray, profileImageSmall: ByteArray)

    fun deleteObject(pin: Pin)

    fun deleteObject(group: Group)

    fun deleteObject(user: User)

    fun getObject(pin: Pin): String

    fun getObject(file: String): String

}
