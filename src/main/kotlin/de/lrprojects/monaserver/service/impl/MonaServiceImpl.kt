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
import kotlin.jvm.optionals.getOrElse

@Service

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
        val authentication = SecurityContextHolder.getContext().authentication
        return if (withImages == null || !withImages) {
            pinRepository.getPinsFromIds(ids?.let { StringHelper.listToString(it) }, username, groupId, authentication.name).map {
                it.toPinWithOptionalImage(null)
            }.toMutableList()
        } else {
            pinRepository.getImagesFromIds(ids?.let { StringHelper.listToString(it) }, username, groupId, authentication.name).map {
                it.first.toPinWithOptionalImage(it.second)
            }.toMutableList()
        }
    }
}