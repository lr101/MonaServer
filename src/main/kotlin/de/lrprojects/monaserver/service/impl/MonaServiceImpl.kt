package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Mona
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.repository.MonaRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.hibernate.SessionFactory
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.jvm.Throws
import kotlin.jvm.optionals.getOrElse

@Service

class MonaServiceImpl(
    @Autowired val monaRepository: MonaRepository,
    @Autowired val pinService: PinService,
    @Autowired val imageHelper: ImageHelper
) : MonaService {

    @Throws(EntityNotFoundException::class)
    override fun getPinImage(pinId: Long): ByteArray {
        return monaRepository.findByPinId(pinId).getOrElse { throw EntityNotFoundException("Pin does not exist") }.image
    }

    @Throws(EntityNotFoundException::class)
    override fun addPinImage(pinId: Long, image: ByteArray): ByteArray {
        val mona =  monaRepository.findByPinId(pinId).getOrElse { throw EntityNotFoundException("Pin does not exist") }
        mona.image = imageHelper.getPinImage(image)
        return monaRepository.save(mona).image
    }

    override fun getPinImagesByIds(ids: MutableList<Long>, compression: Int?, height: Int?, username: String): MutableList<ByteArray> {
        return monaRepository.getImagesFromIds(StringHelper.listToString(ids), username)
    }
}