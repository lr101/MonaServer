package de.lrprojects.monaserver.dto

import de.lrprojects.monaserver.model.GroupSmall
import de.lrprojects.monaserver.model.Visibility
import jakarta.persistence.Entity
import lombok.Data
import java.util.*


open class SmallGroupDto(
    val visibility: Int,
    val groupId: UUID,
    val name: String
)
fun SmallGroupDto.toSmallGroup() = GroupSmall(this.groupId, this.name, Visibility.fromValue(this.visibility))