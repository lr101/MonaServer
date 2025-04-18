package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver.service.api.NotificationService
import de.lrprojects.monaserver_api.api.AdminApiDelegate
import de.lrprojects.monaserver_api.model.AdminMailDto
import de.lrprojects.monaserver_api.model.NotificationDto
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component
import java.util.*

@Component
class AdminController(
    private val emailService: EmailService,
    private val notificationService: NotificationService
): AdminApiDelegate {

    override fun sendAdminMail(adminMailDto: AdminMailDto): ResponseEntity<Void> {
        try {
            var content: String? = null
            if (adminMailDto.messageHtml != null) {
                content = Base64.getDecoder().decode(adminMailDto.messageHtml).decodeToString()
            }
            emailService.sendRoundMail(adminMailDto.mails, adminMailDto.subject, adminMailDto.message, content)
            return ResponseEntity.ok().build()
        } catch (e: IllegalArgumentException) {
            return ResponseEntity.badRequest().build()
        }
    }

    override fun sendNotification(notificationDto: NotificationDto): ResponseEntity<Void> {
        notificationService.sendNotificationToTopics(
            notificationDto.body,
            notificationDto.title,
            notificationDto.topic,
        )
        return ResponseEntity(HttpStatus.CREATED)
    }
}