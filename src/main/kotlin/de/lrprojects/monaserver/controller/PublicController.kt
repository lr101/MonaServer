package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.PublicApiDelegate
import de.lrprojects.monaserver.model.InfoDto
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PublicController : PublicApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun getServerInfo(): ResponseEntity<MutableList<InfoDto>> {
        log.info("Attempting to get public server info")
        // TODO unimplemented
        return ResponseEntity.ok(mutableListOf())
    }


}