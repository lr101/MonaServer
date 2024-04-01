package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.UserInfo
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
        pin.user = userRepository.findById(newPin.userId).orElseThrow()
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

    override fun deletePin(pinId: UUID) {
        pinRepository.deleteById(pinId)
    }

    override fun getPin(pinId: UUID): Pin {
        return pinRepository.findById(pinId).orElseThrow{ EntityNotFoundException("pin not found") }
    }

    override fun getPinCreationUsername(pinId: UUID): UserInfo {
        val pin = pinRepository.findById(pinId).orElseThrow()
        return UserInfo().apply {
            username = pin.user!!.username
            userId = pin.user!!.id
        }
    }

    override fun getPinsByGroup(currentUserId: UUID, groupId: UUID, date: OffsetDateTime): MutableList<Pin> {
        return pinRepository.findPinsByGroupAndDate(currentUserId, groupId, date);
    }

    override fun getPinsByIdsAndUsername(currentUserId: UUID, userId: UUID, ids: MutableList<UUID>): MutableList<Pin> {
        return pinRepository.findPinsOfUserInIds(userId, currentUserId, StringHelper.listToString(ids))
    }

    override fun getPinsByUsernameAndGroup(currentUserId: UUID, userId: UUID, groupId: UUID): MutableList<Pin> {
        return pinRepository.findPinsOfUserAndGroup(userId, currentUserId, groupId)
    }
}