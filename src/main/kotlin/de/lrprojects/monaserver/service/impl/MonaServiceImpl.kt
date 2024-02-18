package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toPinWithOptionalImage
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.model.Pin
import de.lrprojects.monaserver.model.PinWithOptionalImage
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Date
import kotlin.jvm.optionals.getOrElse

@Service
@Transactional
class MonaServiceImpl(
    @Autowired val pinRepository: PinRepository,
    @Autowired val pinService: PinService,
    @Autowired val imageHelper: ImageHelper
) : MonaService {

    @Throws(EntityNotFoundException::class)
    override fun getPinImage(pinId: Long): ByteArray {
        return pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }.image!!
    }

    @Throws(EntityNotFoundException::class)
    override fun addPinImage(pinId: Long, image: ByteArray): ByteArray {
        val pin = pinRepository.findById(pinId).getOrElse { throw EntityNotFoundException("pin not found") }
        val processedImage = imageHelper.getPinImage(image)
        pin.image = processedImage
        pinRepository.save(pin)
        return processedImage
    }

    override fun getPinImagesByIds(ids: MutableList<Long>?, compression: Int?, height: Int?, username: String?, groupId: Long?, withImages: Boolean?): MutableList<PinWithOptionalImage> {
        val authentication = SecurityContextHolder.getContext().authentication.name
        return if (withImages == null || !withImages) {
            pinRepository.getPinsFromIds(ids?.toTypedArray(), username, groupId, authentication).map {
                PinWithOptionalImage(
                    it[0] as Long,
                    (it[1] as Date).toInstant()?.atOffset(ZoneOffset.UTC),
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as String)
                    )
            }.toMutableList()
        } else {
            pinRepository.getImagesFromIds(ids?.toTypedArray(), username, groupId, authentication).map {
                val pin = PinWithOptionalImage(
                    it[0] as Long,
                    (it[1] as Date).toInstant()?.atOffset(ZoneOffset.UTC),
                    (it[2] as Double).toBigDecimal(),
                    (it[3] as Double).toBigDecimal(),
                    (it[4] as String)
                )
                pin.image = (it[5] as ByteArray?)
                pin
            }.toMutableList()
        }
    }
}