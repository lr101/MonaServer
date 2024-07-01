package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import jakarta.persistence.EntityNotFoundException
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.ZoneOffset
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
        return pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }.image!!
    }

    @Throws(EntityNotFoundException::class)
    override fun addPinImage(pinId: UUID, image: ByteArray): ByteArray {
        val pin = pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }
        val processedImage = imageHelper.getPinImage(image)
        pin.image = processedImage
        pinRepository.save(pin)
        return processedImage
    }

    override fun getPinImagesByIds(ids: MutableList<UUID>?, compression: Int?, height: Int?, userId: UUID?, groupId: UUID?, withImages: Boolean?): MutableList<PinWithOptionalImageDto> {
        val authentication = SecurityContextHolder.getContext().authentication.name
        return if (withImages == null || !withImages) {
            pinRepository.getPinsFromIds(ids?.toTypedArray(), userId, groupId, authentication).map {
                PinWithOptionalImageDto(
                    it[0] as UUID,
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as UUID)).also { t ->
                        t.creationDate = (it[1] as Date).toInstant()?.atOffset(ZoneOffset.UTC)
                }
            }.toMutableList()
        } else {
            pinRepository.getImagesFromIds(ids?.toTypedArray(), userId, groupId, authentication).map {
                PinWithOptionalImageDto(
                    it[0] as UUID,
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as UUID)
                ).also { t ->
                    t.creationDate = (it[1] as Date).toInstant()?.atOffset(ZoneOffset.UTC)
                    t.image = (it[5] as ByteArray?)
                }
            }.toMutableList()
        }
    }
}