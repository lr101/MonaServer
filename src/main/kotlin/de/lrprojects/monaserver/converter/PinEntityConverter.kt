package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver_api.model.PinWithOptionalImageDto

fun Pin.toPinModelWithImage(imageUrl: String?) = PinWithOptionalImageDto().also {
    it.id = this.id!!
    it.creationDate = this.creationDate!!
    it.latitude = this.latitude.toBigDecimal()
    it.longitude = this.longitude.toBigDecimal()
    it.creationUser = this.user!!.id!!
    it.groupId  = this.group?.id!!
    it.image = imageUrl
}