package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toPinInfo
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.PinInfo
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service

class PinServiceImpl constructor(
    @Autowired val pinRepository: PinRepository, 
    @Autowired val userRepository: UserRepository,
) : PinService {

    @Transactional
    override fun createPin(newPin: NewPin): Pin {
        var pin = Pin()
        pin.user = userRepository.findById(newPin.username).orElseThrow()
        pin.latitude = newPin.latitude.toDouble()
        pin.longitude = newPin.longitude.toDouble()
        pin.creationDate = Date() //TODO
        pin = pinRepository.save(pin)
        pinRepository.setImage(pin.id!!, newPin.image)
        return pin
    }

    override fun deletePin(pinId: Long) {
        pinRepository.deleteById(pinId)
    }

    override fun getPin(pinId: Long): PinInfo {
        val pin = pinRepository.findById(pinId).orElseThrow()
        val group = pinRepository.findGroupOfPin(pinId).orElseThrow()
        return pin.toPinInfo(group)
    }

    override fun getPinCreationUsername(pinId: Long): String {
        val pin = pinRepository.findById(pinId).orElseThrow()
        return pin.user!!.username!!
    }

    override fun getPinsByGroup(currentUsername: String, groupId: Long, date: OffsetDateTime): MutableList<Pin> {
        return pinRepository.findPinsByGroupAndDate(currentUsername, groupId, date);
    }

    override fun getPinsByIdsAndUsername(currentUsername: String, username: String, ids: MutableList<Long>): MutableList<Pin> {
        return pinRepository.findPinsOfUserInIds(username, currentUsername, StringHelper.listToString(ids))
    }

    override fun getPinsByUsername(currentUsername: String, username: String): MutableList<Pair<Pin, Long>> {
        return pinRepository.findPinsWithGroupOfUser(username, currentUsername)
    }

    override fun getPinsByUsernameAndGroup(currentUsername: String, username: String, groupId: Long): MutableList<Pin> {
        return pinRepository.findPinsOfUserAndGroup(username, currentUsername, groupId)
    }
}