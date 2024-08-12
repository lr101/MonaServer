package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinWithoutImageDto


fun Pin.toPinModel() = PinWithoutImageDto(
    this.id,
    this.creationDate,
    this.latitude.toBigDecimal(),
    this.longitude.toBigDecimal(),
    this.user?.id,
    this.group?.id
)
