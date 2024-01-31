package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PublicApi
import de.lrprojects.monaserver.model.Info
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PublicController : PublicApi {
    override fun getServerInfo(): ResponseEntity<MutableList<Info>> {
        return super.getServerInfo()
    }

}