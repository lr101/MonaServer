package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.GroupPin
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.repository.GroupPinRepository
import de.lrprojects.monaserver.service.api.GroupPinService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class GroupPinServiceImpl constructor(
    @Autowired val groupPinRepository: GroupPinRepository
) : GroupPinService {

    @Transactional
    override fun addPinToGroup(pinId: Long, groupId: Long) {
        val groupPin = GroupPin()
        groupPin.groupId = groupId
        groupPin.id = pinId
        groupPinRepository.save(groupPin)
    }
}