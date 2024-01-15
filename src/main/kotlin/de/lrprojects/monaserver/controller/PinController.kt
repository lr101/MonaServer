package de.lrprojects.monaserver.controller

import org.openapitools.api.PinsApi
import org.openapitools.model.NewPin
import org.openapitools.model.Pin
import org.openapitools.model.PinInfo
import org.springframework.http.ResponseEntity
import java.time.OffsetDateTime

class PinController : PinsApi {
    override fun createPin(newPin: NewPin?): ResponseEntity<Pin> {
        return super.createPin(newPin)
    }

    override fun deletePin(pinId: Long?): ResponseEntity<Void> {
        return super.deletePin(pinId)
    }

    override fun getPin(pinId: Long?): ResponseEntity<PinInfo> {
        return super.getPin(pinId)
    }

    override fun getPinCreationUsername(pinId: Long?): ResponseEntity<String> {
        return super.getPinCreationUsername(pinId)
    }

    override fun getPinImage(pinId: Long?): ResponseEntity<ByteArray> {
        return super.getPinImage(pinId)
    }

    override fun getPinImagesByIds(
        ids: MutableList<Long>?,
        compression: Int?,
        height: Int?
    ): ResponseEntity<MutableList<ByteArray>> {
        return super.getPinImagesByIds(ids, compression, height)
    }

    override fun getPinsByGroup(groupId: Long?, date: OffsetDateTime?): ResponseEntity<MutableList<Pin>> {
        return super.getPinsByGroup(groupId, date)
    }

    override fun getPinsByIdsAndUsername(
        username: String?,
        ids: MutableList<Long>?
    ): ResponseEntity<MutableList<Pin>> {
        return super.getPinsByIdsAndUsername(username, ids)
    }

    override fun getPinsByUsername(username: String?): ResponseEntity<MutableList<Pin>> {
        return super.getPinsByUsername(username)
    }

    override fun getPinsByUsernameAndGroup(username: String?, groupId: Long?): ResponseEntity<MutableList<Pin>> {
        return super.getPinsByUsernameAndGroup(username, groupId)
    }


}