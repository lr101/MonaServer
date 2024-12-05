package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.properties.RoleConstants.ADMIN_ROLE
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver_api.api.AdminApiDelegate
import de.lrprojects.monaserver_api.model.AdminMailDto
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.stereotype.Component

@Component
class AdminController(
    private val emailService: EmailService
): AdminApiDelegate {

    @PreAuthorize("hasRole('$ADMIN_ROLE')")
    override fun sendAdminMail(adminMailDto: AdminMailDto): ResponseEntity<Void> {
        emailService.sendRoundMail(adminMailDto.mails, adminMailDto.subject, adminMailDto.message, adminMailDto.messageHtml)
        return ResponseEntity.ok().build()
    }
}