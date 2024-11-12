package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.config.MinioProperties
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.impl.ObjectServiceImpl.Companion.getGroupFileProfile
import io.minio.MinioClient
import io.minio.PutObjectArgs
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.client.RestTemplate
import org.springframework.web.client.getForEntity
import java.io.ByteArrayInputStream
import java.net.URI


@Service
class ImageMigrationService(
    private val pinRepository: PinRepository,
    private val minioClient: MinioClient,
    private val minioProperties: MinioProperties,
    private val groupRepository: GroupRepository,
    private val userRepository: UserRepository,
    private val imageHelper: ImageHelper,
    private val objectService: ObjectService
) {

    @Transactional
    fun migratePinImagesToMinio(batchSize: Int = 100) {
        var pageNumber = 0
        var pinsWithImages: List<Pin>

        do {
            // Retrieve a batch of Pins with non-null pinImage data
            val pageRequest = PageRequest.of(pageNumber, batchSize)
            pinsWithImages = pinRepository.findPinsByPinImageNotNull(pageRequest)

            pinsWithImages.forEach { pin ->
                val objectName = "${pin.id}.png"
                val imageData = pin.pinImage

                try {
                    // Upload pinImage to MinIO if it exists
                    if (imageData != null) {
                        minioClient.putObject(
                            PutObjectArgs.builder()
                                .bucket(minioProperties.bucketName)
                                .`object`("pins/${pin.id}.png")
                                .stream(ByteArrayInputStream(imageData), imageData.size.toLong(), -1)
                                .contentType("image/png")
                                .build()
                        )
                    }
                } catch (e: Exception) {
                    log.error("Failed to migrate image for pin ${pin.id}: ${e.message}")
                }
            }
            log.info("Finished migrating batch $pageNumber")
            pageNumber++  // Move to the next page of pins

        } while (pinsWithImages.isNotEmpty())

       log.info("Migration of pin images to MinIO completed.")
    }

    @Transactional
    fun migrateUserProfileToMinio(batchSize: Int = 100) {
        var pageNumber = 0
        var userEntites: List<User>

        do {
            // Retrieve a batch of Pins with non-null pinImage data
            val pageRequest = PageRequest.of(pageNumber, batchSize)
            userEntites = userRepository.findUserByProfilePictureNotNull(pageRequest)

            userEntites.forEach { user ->

                try {
                    // Upload pinImage to MinIO if it exists
                    if (user.profilePicture != null) {
                        minioClient.putObject(
                            PutObjectArgs.builder()
                                .bucket(minioProperties.bucketName)
                                .`object`("users/${user.id}/profile.png")
                                .stream(ByteArrayInputStream(user.profilePicture), user.profilePicture!!.size.toLong(), -1)
                                .contentType("image/png")
                                .build()
                        )
                    }
                    if (user.profilePictureSmall != null) {
                        minioClient.putObject(
                            PutObjectArgs.builder()
                                .bucket(minioProperties.bucketName)
                                .`object`("users/${user.id}/profile_small.png")
                                .stream(ByteArrayInputStream(user.profilePictureSmall), user.profilePictureSmall!!.size.toLong(), -1)
                                .contentType("image/png")
                                .build()
                        )
                    }
                } catch (e: Exception) {
                    log.error("Failed to migrate image for user ${user.id}: ${e.message}")
                }
            }
            log.info("Finished migrating batch $pageNumber")
            pageNumber++  // Move to the next page of pins

        } while (userEntites.isNotEmpty())

        log.info("Migration of user images to MinIO completed.")
    }


    @Transactional
    fun migrateGroupImagesToMinio() {
         val groups = groupRepository.findAll()

        groups.forEach { group ->
            val objectName = "group_pin_${group.id}.png"
            val imageData = group.pinImage

            try {
                // Upload pinImage to MinIO if it exists
                if (imageData != null) {
                    minioClient.putObject(
                        PutObjectArgs.builder()
                            .bucket(minioProperties.bucketName)
                            .`object`("groups/${group.id}/group_pin.png")
                            .stream(ByteArrayInputStream(imageData), imageData.size.toLong(), -1)
                            .contentType("image/png")
                            .build()
                    )
                }
                if (group.groupProfile != null) {
                    minioClient.putObject(
                        PutObjectArgs.builder()
                            .bucket(minioProperties.bucketName)
                            .`object`("groups/${group.id}/group_profile.png")
                            .stream(ByteArrayInputStream(group.groupProfile), group.groupProfile!!.size.toLong(), -1)
                            .contentType("image/png")
                            .build()
                    )
                }
            } catch (e: Exception) {
                log.error("Failed to migrate image for group ${group.id}: ${e.message}")
            }
        }

        log.info("Migration of group images to MinIO completed.")
    }

    @Transactional
    fun createSmallGroupImages() {
        val groups = groupRepository.findAll()

        groups.forEach { group ->
            try {
                val groupProfile = objectService.getObject(getGroupFileProfile(group))
                val restTemplate = RestTemplate()
                val result = restTemplate.getForEntity<ByteArray>(URI.create(groupProfile))
                // Check if the group has a profile image to generate a smaller version
                if (result.statusCode == HttpStatus.OK) {
                    val smallImageData = imageHelper.getProfileImageSmall(result.body!!)

                    // Upload the small group image to MinIO
                    minioClient.putObject(
                        PutObjectArgs.builder()
                            .bucket(minioProperties.bucketName)
                            .`object`("groups/${group.id}/group_profile_small.png")
                            .stream(ByteArrayInputStream(smallImageData), smallImageData.size.toLong(), -1)
                            .contentType("image/png")
                            .build()
                    )
                    log.info("Successfully created and migrated small image for group ${group.id}")
                } else {
                    log.warn("No group profile image found for group ${group.id}, skipping.")
                }
            } catch (e: Exception) {
                log.error("Failed to create small image for group ${group.id}: ${e.message}")
            }
        }

        log.info("Creation of small group images completed.")
    }


    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }
}
