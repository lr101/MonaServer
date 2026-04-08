package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.NotificationService
import de.lrprojects.monaserverapi.api.AdminApiDelegate
import de.lrprojects.monaserverapi.model.AdminMailDto
import de.lrprojects.monaserverapi.model.NotificationDto
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component
import java.util.*

@Component
class AdminController(
    private val emailService: EmailService,
    private val notificationService: NotificationService
): AdminApiDelegate {

    override fun sendAdminMail(adminMailDto: AdminMailDto?): ResponseEntity<Unit> {
        try {
            if (adminMailDto == null) {
                return ResponseEntity.badRequest().build()
            }
            var content: String? = null
            if (adminMailDto.messageHtml != null) {
                content = Base64.getDecoder().decode(adminMailDto.messageHtml).decodeToString()
            }
            emailService.sendRoundMail(adminMailDto.mails, adminMailDto.subject, adminMailDto.message, content)
            return ResponseEntity.ok().build()
        } catch (_: IllegalArgumentException) {
            return ResponseEntity.badRequest().build()
        }
    }

    override fun sendNotification(notificationDto: NotificationDto): ResponseEntity<Unit> {
        notificationService.sendNotificationToTopics(
            notificationDto.body,
            notificationDto.title,
            notificationDto.topic,
        )
        return ResponseEntity(HttpStatus.CREATED)
    }
}