package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.openapitools.model.NewPin
import org.openapitools.model.PinInfo
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime

@Service
@Transactional
class PinServiceImpl(@Autowired val pinRepository: PinRepository) : PinService {
    override fun createPin(newPin: NewPin?): Pin {
        TODO("Not yet implemented")
    }

    override fun deletePin(pinId: Long?): Void {
        TODO("Not yet implemented")
    }

    override fun getPinEntity(pinId: Long): Pin {
        val pin = pinRepository.findById(pinId);
        if (pin.isPresent) {
            return pin.get()
        } else {
            throw EntityNotFoundException("Pin not found")
        }
    }

    override fun getPin(pinId: Long?): PinInfo {
        TODO("Not yet implemented")
    }

    override fun getPinCreationUsername(pinId: Long?): String {
        TODO("Not yet implemented")
    }

    override fun getPinsByGroup(groupId: Long?, date: OffsetDateTime?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByIdsAndUsername(username: String?, ids: MutableList<Long>?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsername(username: String?): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsernameAndGroup(username: String?, groupId: Long?): MutableList<Pin> {
        TODO("Not yet implemented")
    }
}