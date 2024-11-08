package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toPinModelWithImage
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver_api.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.LikeService
import de.lrprojects.monaserver.service.api.MonaService
import jakarta.persistence.EntityNotFoundException
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*
import kotlin.jvm.optionals.getOrElse

@Service
@Transactional
class MonaServiceImpl(
    private val pinRepository: PinRepository,
    private val imageHelper: ImageHelper,
    private val likeService: LikeService
) : MonaService {

    @Throws(EntityNotFoundException::class)
    override fun getPinImage(pinId: UUID): ByteArray {
        return pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }.pinImage!!
    }

    @Throws(EntityNotFoundException::class)
    override fun addPinImage(pinId: UUID, image: ByteArray): ByteArray {
        val pin = pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }
        val processedImage = imageHelper.getPinImage(image)
        pin.pinImage = processedImage
        pinRepository.save(pin)
        return processedImage
    }

    override fun getPinImagesByIds(
        ids: List<UUID>?,
        compression: Int?,
        height: Int?,
        userId: UUID?,
        groupId: UUID?,
        withImages: Boolean?,
        updatedAfter: OffsetDateTime?,
        pageable: Pageable,
    ): Page<PinWithOptionalImageDto> {
        val authentication = UUID.fromString(SecurityContextHolder.getContext().authentication.name)
        return pinRepository
            .getImagesFromIds(ids?.toTypedArray(), userId, groupId, authentication, updatedAfter, pageable)
            .map {
                it.toPinModelWithImage(
                    withImages != null && withImages,
                    likeService.likeCountByPin(it.id!!, authentication)
                )
            }
    }
}