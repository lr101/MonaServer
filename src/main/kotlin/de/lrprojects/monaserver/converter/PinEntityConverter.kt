package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserverapi.model.PinRequestDto
import de.lrprojects.monaserverapi.model.PinWithOptionalImageDto

fun Pin.toPinModelWithImage(imageUrl: String?) = PinWithOptionalImageDto(
    id = this.id!!,
    creationDate = this.creationDate!!,
    latitude = this.latitude.toBigDecimal(),
    longitude = this.longitude.toBigDecimal(),
    creationUser = this.user!!.id!!,
    groupId  = this.group?.id!!,
    image = imageUrl,
    description = this.description,
)

fun PinRequestDto.toEntity() = Pin(
    creationDate = this.creationDate,
    latitude = this.latitude.toDouble(),
    longitude = this.longitude.toDouble(),
    description = this.description
)