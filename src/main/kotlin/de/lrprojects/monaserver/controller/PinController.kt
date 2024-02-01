package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PinsApi
import de.lrprojects.monaserver.api.PinsApiDelegate
import de.lrprojects.monaserver.model.NewPin
import de.lrprojects.monaserver.model.Pin
import de.lrprojects.monaserver.model.PinInfo
import de.lrprojects.monaserver.service.api.MonaService
import de.lrprojects.monaserver.service.api.PinService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PinController (
    @Autowired val pinService: PinService,
    @Autowired val monaService: MonaService
) : PinsApiDelegate {


    override fun createPin(newPin: NewPin): ResponseEntity<Pin> {
        val pin = pinService.createPin(newPin)
    }

    override fun deletePin(pinId: Long): ResponseEntity<Void> {
        pinService.deletePin(pinId)
    }

    override fun getPin(pinId: Long): ResponseEntity<PinInfo> {
        val pin = pinService.getPin(pinId)
    }

    override fun getPinCreationUsername(pinId: Long): ResponseEntity<String> {
        val user = pinService.getPinCreationUsername(pinId)
    }

    override fun getPinImage(pinId: Long): ResponseEntity<ByteArray> {
        val image = monaService.getPinImage(pinId)
    }

    override fun getPinImagesByIds(
        ids: MutableList<Long>,
        groupId: Long?,
        username: String?,
        withImage: Boolean?,
        compression: Int?,
        height: Int?
    ): ResponseEntity<MutableList<Pin>> {
        val images = monaService.getPinImagesByIds(ids,compression, height, username, groupId, withImage)
    }


}