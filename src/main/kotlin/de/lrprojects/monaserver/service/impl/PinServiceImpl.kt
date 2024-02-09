package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toPinInfo
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.PinInfo
import de.lrprojects.monaserver.repository.GroupRepository
import jakarta.persistence.EntityNotFoundException
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service

class PinServiceImpl constructor(
    @Autowired val pinRepository: PinRepository, 
    @Autowired val userRepository: UserRepository,
    @Autowired val groupRepository: GroupRepository
) : PinService {

    @Transactional
    override fun createPin(newPin: NewPin): Pin {
        var pin = Pin()
        pin.user = userRepository.findById(newPin.username).orElseThrow()
        pin.latitude = newPin.latitude.toDouble()
        pin.longitude = newPin.longitude.toDouble()
        pin.creationDate = Date() //TODO
        pin.image = newPin.image
        val group =  groupRepository.findById(newPin.groupId).orElseThrow{ EntityNotFoundException("group does not exist")}
        pin = pinRepository.save(pin)
        group.pins.add(pin)
        groupRepository.save(group)
        return pin
    }

    override fun deletePin(pinId: Long) {
        pinRepository.deleteById(pinId)
    }

    override fun getPin(pinId: Long): Pin {
        return pinRepository.findById(pinId).orElseThrow{ EntityNotFoundException("pin not found") }
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