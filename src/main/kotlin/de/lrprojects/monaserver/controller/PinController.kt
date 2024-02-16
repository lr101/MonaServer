package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PinsApiDelegate
import de.lrprojects.monaserver.converter.toPinModel
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.Pin
import de.lrprojects.monaserver.model.PinInfo
import de.lrprojects.monaserver.model.PinWithOptionalImage
import de.lrprojects.monaserver.service.api.GroupService
import de.lrprojects.monaserver.service.api.MemberService
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import jakarta.persistence.EntityNotFoundException
import mu.KotlinLogging
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component


@Component
class PinController (
    @Autowired val pinService: PinService,
    @Autowired val monaService: MonaService,
    @Autowired val memberService: MemberService
) : PinsApiDelegate {

    private val logger = KotlinLogging.logger {}

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
    override fun deletePin(pinId: Long): ResponseEntity<Void> {
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
    override fun getPin(pinId: Long): ResponseEntity<Pin> {
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
    override fun getPinCreationUsername(pinId: Long): ResponseEntity<String> {
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
    override fun getPinImage(pinId: Long): ResponseEntity<ByteArray> {
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
        ids: MutableList<Long>?,
        groupId: Long?,
        username: String?,
        withImage: Boolean?,
        compression: Int?,
        height: Int?
    ): ResponseEntity<MutableList<PinWithOptionalImage>> {
        return try {
            val images = monaService.getPinImagesByIds(ids,compression, height, username, groupId, withImage)
            ResponseEntity.ok(images)
        } catch (e: EntityNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }


}