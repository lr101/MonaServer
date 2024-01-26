package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.GroupPin
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.repository.GroupPinRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.api.GroupPinService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime

@Service
@Transactional
class GroupPinServiceImpl constructor(
    @Autowired val groupPinRepository: GroupPinRepository,
    @Autowired val pinRepository: PinRepository
) : GroupPinService {

    override fun addPinToGroup(pinId: Long, groupId: Long) {
        val groupPin = GroupPin()
        groupPin.groupId = groupId
        groupPin.id = pinId
        groupPinRepository.save(groupPin)
    }

    override fun getPinsByGroup(groupId: Long, date: OffsetDateTime): List<Pin> {
        return groupPinRepository.findGroupPinsByGroupId(groupId).filter { e -> e.creationDate!!.toInstant() < date.toInstant() }
    }
}