package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.helper.StringHelper
import de.lrprojects.monaserver.model.PinRequestDto
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service

class PinServiceImpl(
    val pinRepository: PinRepository,
    val userRepository: UserRepository,
    val groupRepository: GroupRepository
) : PinService {

    @Transactional
    override fun createPin(newPin: PinRequestDto): Pin {
        var pin = Pin()
        pin.user = userRepository.findById(newPin.userId).orElseThrow()
        pin.latitude = newPin.latitude.toDouble()
        pin.longitude = newPin.longitude.toDouble()
        pin.creationDate = newPin.creationDate
        pin.pinImage = newPin.image
        pin.group =  groupRepository.findById(newPin.groupId).orElseThrow{ EntityNotFoundException("group does not exist")}
        pin = pinRepository.save(pin)
        return pin
    }

    override fun deletePin(pinId: UUID) {
        pinRepository.deleteById(pinId)
    }

    override fun getPin(pinId: UUID): Pin {
        return pinRepository.findById(pinId).orElseThrow { EntityNotFoundException("pin not found") }
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