package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PinsApiDelegate
import de.lrprojects.monaserver.converter.toPinModelWithImage
import de.lrprojects.monaserver.model.PinRequestDto
import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.model.PinsSyncDto
import de.lrprojects.monaserver.service.api.DeleteLogService
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.time.OffsetDateTime
import java.util.*

@Component
class PinController(
    private val pinService: PinService,
    private val monaService: MonaService,
    private val deletedLogService: DeleteLogService
) : PinsApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("hasAuthority('ADMIN') " +
            "|| (@guard.isGroupMember(authentication, #pinRequestDto.groupId)" +
            "&& @guard.isSameUser(authentication, #pinRequestDto.userId))"
    )
    override fun createPin(pinRequestDto: PinRequestDto): ResponseEntity<PinWithOptionalImageDto> {
        log.info("Attempting to create pin for groupId: ${pinRequestDto.groupId}, userId: ${pinRequestDto.userId}")
        val pin = pinService.createPin(pinRequestDto)
        log.info("Pin created for groupId: ${pinRequestDto.groupId}, userId: ${pinRequestDto.userId}")
        return ResponseEntity(pin.toPinModelWithImage(true), HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isPinCreator(authentication, #pinId) || @guard.isPinGroupAdmin(authentication, #pinId)")
    override fun deletePin(pinId: UUID): ResponseEntity<Void>? {
        log.info("Attempting to delete pin with ID: $pinId")
        pinService.deletePin(pinId)
        log.info("Pin deleted with ID: $pinId")
        return ResponseEntity.ok().build()
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPin(pinId: UUID, withImage: Boolean): ResponseEntity<PinWithOptionalImageDto> {
        log.info("Attempting to get pin with ID: $pinId")
        val pin = pinService.getPin(pinId)
        log.info("Retrieved pin with ID: $pinId")
        return ResponseEntity.ok(pin.toPinModelWithImage(withImage))
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinImage(pinId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get pin image for pin with ID: $pinId")
        val image = monaService.getPinImage(pinId)
        log.info("Retrieved pin image for pin with ID: $pinId")
        return ResponseEntity.ok(image)
    }

    @PreAuthorize("@guard.isPinsCreator(authentication, #ids) || @guard.isPinsPublicOrMember(authentication, #ids) ")
    override fun getPinImagesByIds(
        ids: List<UUID>?,
        groupId: UUID?,
        userId: UUID?,
        withImage: Boolean,
        compression: Int?,
        height: Int?,
        page: Int?,
        size: Int,
        updatedAfter: OffsetDateTime?
    ): ResponseEntity<PinsSyncDto> {
        log.info("Attempting to get pin images by IDs: $ids, groupId: $groupId, userId: $userId, withImage: $withImage, compression: $compression, height: $height, page: $page, size: $size")
        val pageable: Pageable = if (page != null) {
            PageRequest.of(page, size)
        } else {
            Pageable.unpaged()
        }
        val images = monaService.getPinImagesByIds(ids, compression, height, userId, groupId, withImage, updatedAfter, pageable)
        var deletedPins = emptyList<UUID>()
        if (updatedAfter != null) {
            deletedPins = deletedLogService.getDeletedPins(updatedAfter)
        }
        log.info("Retrieved pin images")
        return ResponseEntity.ok(PinsSyncDto(images.toList(), deletedPins))
    }
}
