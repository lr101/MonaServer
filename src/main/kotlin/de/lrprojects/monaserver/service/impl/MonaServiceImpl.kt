package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.repository.MonaRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.MonaService
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MonaServiceImpl constructor(@Autowired val monaRepository: MonaRepository): MonaService {
    override fun getPinImage(pinId: Long): ByteArray {
        val mona = monaRepository.findByPinId(pinId).orElseThrow()
        return mona.image
    }

    override fun addPinImage(pinId: Long, image: ByteArray): ByteArray {
        val mona = monaRepository.findByPinId(pinId).orElseThrow()
        mona.image = image
        return monaRepository.save(mona).image
    }

    override fun getPinImagesByIds(ids: MutableList<Long>, compression: Int?, height: Int?): List<ByteArray?> {
        val list = ArrayList<ByteArray?>()
        for (id in ids) {
            try {
                list.add(getPinImage(id))
            } catch (e: EntityNotFoundException) {
                list.add(null)
            }

        }
        return list
    }
}