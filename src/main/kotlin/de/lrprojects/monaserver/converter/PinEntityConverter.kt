package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinInfo
import java.time.ZoneOffset


fun Pin.toPinInfo(group: Group) =  PinInfo(
    this.toPinModel(),
    group.convertToGroupSmall()
)

fun Pin.toPinModel() = de.lrprojects.monaserver.model.Pin(
    this.id,
    this.creationDate?.toInstant()?.atOffset(ZoneOffset.UTC),
    this.latitude.toBigDecimal(),
    this.longitude.toBigDecimal(),
    this.user?.username
)