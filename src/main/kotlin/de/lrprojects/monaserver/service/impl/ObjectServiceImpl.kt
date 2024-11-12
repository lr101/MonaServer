package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.config.MinioProperties
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.service.api.ObjectService
import io.minio.GetPresignedObjectUrlArgs
import io.minio.MinioClient
import io.minio.PutObjectArgs
import io.minio.RemoveObjectArgs
import io.minio.http.Method
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.io.ByteArrayInputStream
import java.util.*
import java.util.concurrent.TimeUnit


@Service
class ObjectServiceImpl(
    private val minioClient: MinioClient,
    private val minioProperties: MinioProperties
) : ObjectService {

    private fun createObject(file: String, image: ByteArray) {
        minioClient.putObject(
            PutObjectArgs
                .builder()
                .bucket(minioProperties.bucketName)
                .`object`(file)
                .stream(ByteArrayInputStream(image), image.size.toLong(), -1).build())
    }

    override fun createObject(pin: Pin, image: ByteArray): String {
        createObject("pins/${pin.id}.png", image)
        return getObject(pin)
    }

    override fun createObject(group: Group, imagePin: ByteArray, imageProfile: ByteArray, imageProfileSmall: ByteArray) {
        createObject(getGroupFilePin(group), imagePin)
        createObject(getGroupFileProfile(group), imageProfile)
        createObject(getGroupFileProfileSmall(group), imageProfile)
    }

    override fun createObject(user: User, profileImage: ByteArray, profileImageSmall: ByteArray) {
        createObject(getUserFileProfile(user), profileImage)
        createObject(getUserFileProfileSmall(user), profileImageSmall)
    }

    private fun deleteObject(file: String) {
        minioClient.removeObject(
            RemoveObjectArgs.builder().bucket(minioProperties.bucketName)
                .`object`(file)
                .build()
        )
    }

    override fun deleteObject(pin: Pin) {
        deleteObject("pins/${pin.id}.png")
    }

    override fun deleteObject(group: Group) {
        deleteObject(getGroupFilePin(group))
        deleteObject(getGroupFileProfile(group))
        deleteObject(getGroupFileProfileSmall(group))
    }

    override fun deleteObject(user: User) {
        deleteObject(getUserFileProfile(user))
        deleteObject(getUserFileProfileSmall(user))
    }

    override fun getObject(file: String): String {
        return minioClient.getPresignedObjectUrl(
            GetPresignedObjectUrlArgs
                .builder()
                .method(Method.GET)
                .expiry(30, TimeUnit.MINUTES)
                .bucket(minioProperties.bucketName)
                .`object`(file)
                .build()
        )
    }

    override fun getObject(pin: Pin): String {
        return getObject("pins/${pin.id}.png")
    }

    companion object {
        private val log = LoggerFactory.getLogger(ObjectServiceImpl::class.java)
        fun getGroupFilePin(group: Group) = "groups/${group.id}/group_pin.png"
        fun getGroupFilePin(uuid: UUID) = "groups/${uuid}/group_pin.png"
        fun getGroupFileProfile(group: Group) = "groups/${group.id}/group_profile.png"
        fun getGroupFileProfileSmall(group: Group) = "groups/${group.id}/group_profile_small.png"
        fun getGroupFileProfile(uuid: UUID) = "groups/${uuid}/group_profile.png"
        fun getGroupFileProfileSmall(uuid: UUID) = "groups/${uuid}/group_profile_small.png"
        fun getUserFileProfile(user: User) = "users/${user.id}/profile.png"
        fun getUserFileProfile(uuid: UUID) = "users/${uuid}/profile.png"
        fun getUserFileProfileSmall(user: User) = "users/${user.id}/profile_small.png"
        fun getUserFileProfileSmall(uuid: UUID) = "users/${uuid}/profile_small.png"

    }

}
