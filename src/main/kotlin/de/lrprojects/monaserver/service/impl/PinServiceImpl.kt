package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Mona
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.repository.MonaRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.security.ModelMapper
import de.lrprojects.monaserver.service.api.PinService
import org.openapitools.model.NewPin
import org.openapitools.model.PinInfo
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.sql.SQLException
import java.time.OffsetDateTime
import java.util.*

@Service
@Transactional
class PinServiceImpl constructor(
    @Autowired val pinRepository: PinRepository, 
    @Autowired val userRepository: UserRepository,
    @Autowired val monaRepository: MonaRepository,
    @Autowired val modelMapper: ModelMapper
) : PinService {
    override fun createPin(newPin: NewPin): Pin {
        val pin = Pin()
        pin.user = userRepository.findById(newPin.username).orElseThrow()
        pin.latitude = newPin.latitude
        pin.longitude = newPin.longitude
        pin.creationDate = Date() //TODO
        var mona = Mona()
        mona.pin = pin
        mona.image = newPin.image
        mona = monaRepository.save(mona)
        return mona.pin!!
    }

    override fun deletePin(pinId: Long) {
        monaRepository.deleteByPinId(pinId)
    }

    override fun getPin(pinId: Long): PinInfo {
        val pin = pinRepository.findById(pinId).orElseThrow()
        return modelMapper.modelMapper().map(pin, PinInfo::class.java)
    }

    override fun getPinCreationUsername(pinId: Long): String {
        val pin = pinRepository.findById(pinId).orElseThrow()
        return pin.user!!.username!!
    }



    override fun getPinsByIdsAndUsername(username: String, ids: MutableList<Long>): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsername(username: String): MutableList<Pin> {
        TODO("Not yet implemented")
    }

    override fun getPinsByUsernameAndGroup(username: String, groupId: Long): MutableList<Pin> {
        TODO("Not yet implemented")
    }
}