package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PinsApiDelegate
import de.lrprojects.monaserver.converter.toPinModel
import de.lrprojects.monaserver.model.*
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component
import java.util.*


@Component
class PinController (
    private val pinService: PinService,
    private val monaService: MonaService,
) : PinsApiDelegate {

    companion object {
        private val logger = LoggerFactory.getLogger(this::class.java)
    }

    @PreAuthorize("hasAuthority('ADMIN') " +
            "|| (@guard.isGroupMember(authentication, #newPin.groupId)" +
            "&& @guard.isSameUser(authentication, #newPin.username))")
    override fun createPin(newPin: NewPin): ResponseEntity<Pin> {
        return try {
            val pin = pinService.createPin(newPin)
            ResponseEntity(pin.toPinModel(), HttpStatus.CREATED)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isPinCreator(authentication, #pinId) || @guard.isPinGroupAdmin(authentication, #pinId)")
    override fun deletePin(pinId: UUID): ResponseEntity<Void> {
        return try {
            pinService.deletePin(pinId)
            ResponseEntity.ok().build()
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            logger.error(e.message)
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPin(pinId: UUID): ResponseEntity<Pin> {
        return try {
            val pin = pinService.getPin(pinId)
            ResponseEntity.ok(pin.toPinModel())
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinCreationUsername(pinId: UUID): ResponseEntity<UserInfo>? {
        return try {
            val user = pinService.getPinCreationUsername(pinId)
            ResponseEntity.ok(user)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    @PreAuthorize("@guard.isPinPublicOrMember(authentication, #pinId)")
    override fun getPinImage(pinId: UUID): ResponseEntity<ByteArray> {
        return try {
            val image = monaService.getPinImage(pinId)
            ResponseEntity.ok(image)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

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
    ): ResponseEntity<MutableList<PinWithOptionalImage>> {
        return try {
            val images = monaService.getPinImagesByIds(ids,compression, height, userId, groupId, withImage)
            ResponseEntity.ok(images)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }


}