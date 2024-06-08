package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PublicApiDelegate
import de.lrprojects.monaserver.model.Info
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PublicController : PublicApiDelegate {

    override fun getServerInfo(): ResponseEntity<MutableList<Info>> {
        // TODO unimplemented
        return ResponseEntity.ok(mutableListOf())
    }


}