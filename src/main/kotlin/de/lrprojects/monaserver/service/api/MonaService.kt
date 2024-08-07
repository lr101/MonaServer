package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import java.util.*

interface MonaService {


    fun getPinImage(pinId: UUID): ByteArray

    fun addPinImage(pinId: UUID, image: ByteArray): ByteArray

    fun getPinImagesByIds(ids: MutableList<UUID>?, compression: Int?, height: Int?, userId: UUID?, groupId: UUID?, withImages: Boolean?): MutableList<PinWithOptionalImageDto>
}