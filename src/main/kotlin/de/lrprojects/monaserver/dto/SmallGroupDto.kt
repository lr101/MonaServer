package de.lrprojects.monaserver.dto

import de.lrprojects.monaserver.model.GroupSmallDto
import de.lrprojects.monaserver.model.Visibility
import java.util.*


open class SmallGroupDto(
    val visibility: Int,
    val groupId: UUID,
    val name: String
)
fun SmallGroupDto.toSmallGroup() = GroupSmallDto(this.groupId, this.name, Visibility.fromValue(this.visibility))