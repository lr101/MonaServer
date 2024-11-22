package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver_api.model.PinRequestDto
import io.minio.errors.MinioException
import jakarta.persistence.EntityNotFoundException
import org.springframework.cache.annotation.CacheEvict
import org.springframework.cache.annotation.Cacheable
import org.springframework.cache.annotation.Caching
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service

class PinServiceImpl(
    private val pinRepository: PinRepository,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val objectService: ObjectService
) : PinService {

    @Transactional
    override fun createPin(newPin: PinRequestDto): Pin {
        var pin = Pin()
        pin.user = userRepository.findById(newPin.userId).orElseThrow()
        pin.latitude = newPin.latitude.toDouble()
        pin.longitude = newPin.longitude.toDouble()
        pin.creationDate = newPin.creationDate
        pin.group =  groupRepository.findById(newPin.groupId).orElseThrow{ EntityNotFoundException("group does not exist")}
        pin = pinRepository.save(pin)
        objectService.createObject(pin, newPin.image)
        return pin
    }

    @Transactional
    @Caching(
        evict = [
            CacheEvict(value = ["pinById"], key = "{#pinId}")
        ]
    )
    override fun deletePin(pinId: UUID) {
        pinRepository.deleteById(pinId)
        objectService.deletePinObject(pinId)
    }

    override fun deleteObjectsByList(pinIds: List<UUID>) {
        pinIds.forEach { pin ->
            try {
                objectService.deletePinObject(pin)
            } catch (e: MinioException) {
                log.info(e.message)
            }
        }
    }

    override fun getGroupPins(group: Group): List<UUID> {
        return pinRepository.findAllByGroup(group)
    }

    override fun getUserPins(user: User): List<UUID> {
        return pinRepository.findAllByUser(user)
    }

    @Cacheable(value = ["pinById"], key = "{#pinId}")
    override fun getPin(pinId: UUID): Pin {
        return pinRepository.findById(pinId).orElseThrow { EntityNotFoundException("pin not found") }
    }

    companion object {
        private val log = org.slf4j.LoggerFactory.getLogger(this::class.java)
    }

}