package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Boundary
import de.lrprojects.monaserver_api.model.MapInfoDto

fun Boundary.toMapInfoDto() = MapInfoDto().also {
    it.id = this.id
    it.gid0 = this.gid0
    it.gid1 = this.gid1
    it.gid2 = this.gid2
    it.name0 = this.name0
    it.name1 = this.name1
    it.name2 = this.name2
}