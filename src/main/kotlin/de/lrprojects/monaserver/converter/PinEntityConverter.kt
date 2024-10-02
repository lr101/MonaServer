package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinWithOptionalImageDto

fun Pin.toPinModelWithImage(withImage: Boolean) = PinWithOptionalImageDto(
    this.id!!,
    this.creationDate!!,
    this.latitude.toBigDecimal(),
    this.longitude.toBigDecimal(),
    this.user?.id!!,
    this.group?.id!!,
    if (withImage) this.pinImage else null
)
