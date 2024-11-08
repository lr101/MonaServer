package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver_api.api.PublicApiDelegate
import de.lrprojects.monaserver_api.model.InfoDto
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PublicController : PublicApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun getServerInfo(): ResponseEntity<List<InfoDto>> {
        log.info("Attempting to get public server info")
        // TODO unimplemented
        return ResponseEntity.ok(listOf())
    }


}