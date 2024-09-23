package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import jakarta.persistence.EntityNotFoundException
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*
import kotlin.jvm.optionals.getOrElse

@Service
@Transactional
class MonaServiceImpl(
    val pinRepository: PinRepository,
    val imageHelper: ImageHelper
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

    override fun getPinImagesByIds(ids: MutableList<UUID>?, compression: Int?, height: Int?, userId: UUID?, groupId: UUID?, withImages: Boolean?, updatedAfter: Date?, pageable: Pageable): Page<PinWithOptionalImageDto> {
        val authentication = UUID.fromString(SecurityContextHolder.getContext().authentication.name)
        return if (withImages == null || !withImages) {
            pinRepository.getPinsFromIds(ids?.toTypedArray(), userId, groupId, authentication, updatedAfter, pageable).map {
                PinWithOptionalImageDto(
                    it[0] as UUID,
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as UUID),
                    (it[5] as UUID)
                ).also { t -> t.creationDate = (it[1] as Date) }
            }
        } else {
            pinRepository.getImagesFromIds(ids?.toTypedArray(), userId, groupId, authentication, updatedAfter, pageable).map {
                PinWithOptionalImageDto(
                    it[0] as UUID,
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as UUID),
                    (it[6] as UUID)
                ).also { t ->
                    t.creationDate = (it[1] as Date)
                    t.image = (it[5] as ByteArray?)
                }
            }
        }
    }
}