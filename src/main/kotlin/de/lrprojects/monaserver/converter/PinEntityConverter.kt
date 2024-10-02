package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinWithOptionalImageDto

fun Pin.toPinModelWithImage(withImage: Boolean) = PinWithOptionalImageDto().also {
    it.id = this.id!!
    it.creationDate = this.creationDate!!
    it.latitude = this.latitude.toBigDecimal()
    it.longitude = this.longitude.toBigDecimal()
    it.creationUser = this.user!!.id!!
    it.groupId  = this.group?.id!!
    it.image = if (withImage) this.pinImage else null
}
