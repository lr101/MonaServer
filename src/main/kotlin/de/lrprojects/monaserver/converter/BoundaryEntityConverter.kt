package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Boundary
import de.lrprojects.monaserverapi.model.MapInfoDto

fun Boundary.toMapInfoDto() = MapInfoDto(
    id = this.id!!,
    gid0 = this.gid0,
    gid1 = this.gid1,
    gid2 = this.gid2,
    name0 = this.name0,
    name1 = this.name1,
    name2 = this.name2
)