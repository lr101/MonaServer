package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver_api.model.PinRequestDto
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.service.api.GroupPinService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.springframework.stereotype.Service
import kotlin.jvm.optionals.getOrElse

@Service

class GroupPinServiceImpl(
    val pinService: PinService,
    val groupRepository: GroupRepository
) : GroupPinService {

    @Throws(EntityNotFoundException::class)
    override fun addPinToGroup(newPin: PinRequestDto) : Pin {
        val pin = pinService.createPin(newPin)
        val group = groupRepository.findById(newPin.groupId).getOrElse { throw EntityNotFoundException("group not found") }
        group.pins.add(pin)
        groupRepository.save(group)
        return pin
    }


}