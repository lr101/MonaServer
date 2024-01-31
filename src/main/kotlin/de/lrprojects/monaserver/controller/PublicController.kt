package de.lrprojects.monaserver.controller

import org.openapitools.api.PublicApi
import org.openapitools.model.Info
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class PublicController : PublicApi {
    override fun getAgb(): ResponseEntity<Void> {
        return super.getAgb()
    }

    override fun getPrivacyPolicy(): ResponseEntity<Void> {
        return super.getPrivacyPolicy()
    }

    override fun getServerInfo(): ResponseEntity<MutableList<Info>> {
        return super.getServerInfo()
    }

    override fun rootGet(): ResponseEntity<Void> {
        return super.rootGet()
    }

}