package de.lrprojects.monaserver.service.impl

import com.google.cloud.Identity.group
import de.lrprojects.monaserver.converter.toEntity
import de.lrprojects.monaserver.converter.toGroupDto
import de.lrprojects.monaserver.converter.toPinModelWithImage
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.AlreadyExistException
import de.lrprojects.monaserver.excepetion.ImageProcessingException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.DeleteLogService
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.ObjectService
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver.service.api.SeasonService
import de.lrprojects.monaserverapi.model.PinRequestDto
import de.lrprojects.monaserverapi.model.SyncDto
import de.lrprojects.monaserverapi.model.SyncDtoGroupUpdatesInner
import io.minio.errors.MinioException
import jakarta.persistence.EntityNotFoundException
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Service

class PinServiceImpl(
    private val pinRepository: PinRepository,
    private val userRepository: UserRepository,
    private val groupRepository: GroupRepository,
    private val memberService: MemberService,
    private val objectService: ObjectService,
    private val rankingService: RankingService,
    private val seasonService: SeasonService,
    private val deleteLogService: DeleteLogService,
    private val imageHelper: ImageHelper
) : PinService {

    @Transactional
    @Throws(ImageProcessingException::class, EntityNotFoundException::class, UserNotFoundException::class)
    override fun createPin(newPin: PinRequestDto): Pin {
        val user = userRepository.findById(newPin.userId).orElseThrow{ UserNotFoundException("user does not exist") }
        pinRepository.findByCreationDateAndUserAndLatitudeAndLongitude(
            newPin.creationDate!!,
            user,
            newPin.latitude.toDouble(),
            newPin.longitude.toDouble()
        ).ifPresent { throw AlreadyExistException("pin already exists") }
        var pin = newPin.toEntity()
        pin.user = user
        pin.location = rankingService.getBoundaryEntity(pin.latitude, pin.longitude)
        pin.group =  groupRepository.findById(newPin.groupId).orElseThrow{ EntityNotFoundException("group does not exist")}
        pin = pinRepository.save(pin)
        val compressedImage = imageHelper.compressPinImage(newPin.image)
        objectService.createObject(pin, compressedImage)
        return pin
    }

    @Transactional
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

    override fun getSync(lastSeen: OffsetDateTime?): SyncDto {
        val userId = UUID.fromString(SecurityContextHolder.getContext().authentication?.name
            ?: throw IllegalStateException("User not authenticated"))
        val groups = groupRepository.getUserGroups(userId)

        if (groups.isEmpty()) return SyncDto(emptyList(), mutableListOf())

        val groupIds = groups.mapNotNull { it.id }
        val pins = pinRepository.getUpdatedPinsForGroups(groupIds, lastSeen)

        val pinsByGroupId = pins.groupBy { it.group!!.id }

        val deletedPins = lastSeen?.let { deleteLogService.getDeletedPins(it) } ?: emptyList()

        val groupUpdates = groups.map { groupEntity ->
            val seasonItemDto = seasonService.getBestGroupSeason(groupEntity.id!!)
            val groupDto = groupEntity.toGroupDto(memberService, true, objectService, seasonItemDto)
            val pinDtos = pinsByGroupId[groupEntity.id]
                ?.map { it.toPinModelWithImage(null) }
                ?: emptyList()

            SyncDtoGroupUpdatesInner(groupDto, pinDtos)
        }.toMutableList()

        return SyncDto(deletedPins, groupUpdates)
    }

    override fun getPin(pinId: UUID): Pin {
        return pinRepository.findById(pinId).orElseThrow { EntityNotFoundException("pin not found") }
    }

    companion object {
        private val log = org.slf4j.LoggerFactory.getLogger(this::class.java)
    }

}