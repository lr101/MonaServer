package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import org.openapitools.model.PinInfo
import java.time.ZoneOffset


fun Pin.toPinInfo(group: Group) =  PinInfo(
    this.toPinModel(),
    group.convertToGroupSmall()
)

fun Pin.toPinModel() = org.openapitools.model.Pin(
    this.id,
    this.creationDate?.toInstant()?.atOffset(ZoneOffset.UTC),
    this.latitude.toBigDecimal(),
    this.longitude.toBigDecimal(),
    this.user?.username
)