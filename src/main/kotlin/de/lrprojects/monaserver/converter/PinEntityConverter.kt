package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver_api.model.PinLikeDto
import de.lrprojects.monaserver_api.model.PinWithOptionalImageDto

fun Pin.toPinModelWithImage(withImage: Boolean, likes: PinLikeDto) = PinWithOptionalImageDto().also {
    it.id = this.id!!
    it.creationDate = this.creationDate!!
    it.latitude = this.latitude.toBigDecimal()
    it.longitude = this.longitude.toBigDecimal()
    it.creationUser = this.user!!.id!!
    it.groupId  = this.group?.id!!
    it.image = if (withImage) this.pinImage else null
    it.likes = likes
}