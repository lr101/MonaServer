package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinWithOptionalImageDto
import de.lrprojects.monaserver.model.PinWithoutImageDto
import java.time.ZoneOffset


fun Pin.toPinModel() = PinWithoutImageDto(
    this.id,
    this.latitude.toBigDecimal(),
    this.longitude.toBigDecimal(),
    this.user?.id
).also { it.creationDate = this.creationDate?.toInstant()?.atOffset(ZoneOffset.UTC) }

fun Pin.toPinWithOptionalImage(image: ByteArray?) = PinWithOptionalImageDto(
        this.id,
        this.latitude.toBigDecimal(),
        this.longitude.toBigDecimal(),
        this.user?.id,
    ).also {
        it.creationDate = this.creationDate?.toInstant()?.atOffset(ZoneOffset.UTC)
        it.image = this.image
    }