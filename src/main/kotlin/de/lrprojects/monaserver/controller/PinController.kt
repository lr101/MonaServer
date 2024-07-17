package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PinsApiDelegate
import de.lrprojects.monaserver.converter.toPinModel
import de.lrprojects.monaserver.model.PinRequestDto
import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.model.PinWithoutImageDto
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*

@Component
class PinController(
    private val pinService: PinService,
    private val monaService: MonaService,
) : PinsApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("hasAuthority('ADMIN') " +
            "|| (@guard.isGroupMember(authentication, #newPin.groupId)" +
            "&& @guard.isSameUser(authentication, #newPin.userId))")
    override fun createPin(newPin: PinRequestDto): ResponseEntity<PinWithoutImageDto> {
        log.info("Attempting to create pin for groupId: ${newPin.groupId}, userId: ${newPin.userId}")
        val pin = pinService.createPin(newPin)
        log.info("Pin created for groupId: ${newPin.groupId}, userId: ${newPin.userId}")
        return ResponseEntity(pin.toPinModel(), HttpStatus.CREATED)
    }

    @PreAuthorize("@guard.isPinCreator(authentication, #pinId) || @guard.isPinGroupAdmin(authentication, #pinId)")
    override fun deletePin(pinId: UUID): ResponseEntity<Void> {
        log.info("Attempting to delete pin with ID: $pinId")
        pinService.deletePin(pinId)
        log.info("Pin deleted with ID: $pinId")
        return ResponseEntity.ok().build()
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPin(pinId: UUID): ResponseEntity<PinWithoutImageDto> {
        log.info("Attempting to get pin with ID: $pinId")
        val pin = pinService.getPin(pinId)
        log.info("Retrieved pin with ID: $pinId")
        return ResponseEntity.ok(pin.toPinModel())
    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinImage(pinId: UUID): ResponseEntity<ByteArray> {
        log.info("Attempting to get pin image for pin with ID: $pinId")
        val image = monaService.getPinImage(pinId)
        log.info("Retrieved pin image for pin with ID: $pinId")
        return ResponseEntity.ok(image)
    }

    @PreAuthorize("@guard.isPinsPublicOrMember(authentication, #ids) " +
            "&& (#groupId == null || @guard.isGroupVisible(authentication, #groupId))")
    override fun getPinImagesByIds(
        ids: MutableList<UUID>?,
        groupId: UUID?,
        userId: UUID?,
        withImage: Boolean?,
        compression: Int?,
        height: Int?
    ): ResponseEntity<MutableList<PinWithOptionalImageDto>> {
        log.info("Attempting to get pin images by IDs: $ids, groupId: $groupId, userId: $userId, withImage: $withImage, compression: $compression, height: $height")
        val images = monaService.getPinImagesByIds(ids, compression, height, userId, groupId, withImage)
        log.info("Retrieved pin images by IDs: $ids")
        return ResponseEntity.ok(images)
    }
}
