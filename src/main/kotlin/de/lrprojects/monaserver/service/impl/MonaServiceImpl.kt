package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
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
        return pinRepository.getImage(pinId).getOrElse { throw EntityNotFoundException("pin not found") }
    }

    @Throws(EntityNotFoundException::class)
    override fun addPinImage(pinId: Long, image: ByteArray): ByteArray {
        val processedImage = imageHelper.getPinImage(image)
        pinRepository.setImage(pinId, processedImage)
        return processedImage
    }

    override fun getPinImagesByIds(ids: MutableList<Long>, compression: Int?, height: Int?, username: String?, groupId: Long?, withImages: Boolean?): MutableList<ByteArray> {
        pinRepository.getImagesFromIds()
        return pinRepository.getImagesFromIds(StringHelper.listToString(ids), username)
    }
}