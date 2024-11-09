package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver_api.model.PinWithOptionalImageDto
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import java.time.OffsetDateTime
import java.util.*

interface MonaService {


    fun getPinImage(pinId: UUID): String

    fun addPinImage(pinId: UUID, image: ByteArray): String

    fun getPinImagesByIds(
        ids: List<UUID>?,
        compression: Int?,
        height: Int?,
        userId: UUID?,
        groupId: UUID?,
        withImages: Boolean?,
        updatedAfter: OffsetDateTime?,
        pageable: Pageable,
    ): Page<PinWithOptionalImageDto>
}